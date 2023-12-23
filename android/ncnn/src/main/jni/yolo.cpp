// Tencent is pleased to support the open source community by making ncnn available.
//
// Copyright (C) 2021 THL A29 Limited, a Tencent company. All rights reserved.
//
// Licensed under the BSD 3-Clause License (the "License"); you may not use this file except
// in compliance with the License. You may obtain a copy of the License at
//
// https://opensource.org/licenses/BSD-3-Clause
//
// Unless required by applicable law or agreed to in writing, software distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

#include "yolo.h"
#include "log.h"
#include <opencv2/core/core.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include "cpu.h"
#include <string.h>
#include <cstring>
#include <vector>

void slicing(std::vector<Object> &arr, int size)
{
    // Begin and End iterator
    auto first = arr.begin() + size;
    auto last = arr.begin() + arr.size();

    arr.erase(first, last);
}


static float fast_exp(float x)
{
    union
    {
        uint32_t i;
        float f;
    } v{};
    v.i = (1 << 23) * (1.4426950409 * x + 126.93490512f);
    return v.f;
}

static float sigmoid(float x)
{
    return 1.0f / (1.0f + fast_exp(-x));
}
static float intersection_area(const Object &a, const Object &b)
{
    cv::Rect_<float> inter = a.rect & b.rect;
    return inter.area();
}

static void qsort_descent_inplace(std::vector<Object> &faceobjects, int left, int right)
{
    int i = left;
    int j = right;
    float p = faceobjects[(left + right) / 2].prob;

    while (i <= j)
    {
        while (faceobjects[i].prob > p)
            i++;

        while (faceobjects[j].prob < p)
            j--;

        if (i <= j)
        {
            // swap
            std::swap(faceobjects[i], faceobjects[j]);

            i++;
            j--;
        }
    }

    //     #pragma omp parallel sections
    {
        //         #pragma omp section
        {
            if (left < j)
                qsort_descent_inplace(faceobjects, left, j);
        }
        //         #pragma omp section
        {
            if (i < right)
                qsort_descent_inplace(faceobjects, i, right);
        }
    }
}

static void qsort_descent_inplace(std::vector<Object> &faceobjects)
{
    if (faceobjects.empty())
        return;

    qsort_descent_inplace(faceobjects, 0, faceobjects.size() - 1);
}

static void nms_sorted_bboxes(const std::vector<Object> &faceobjects, std::vector<int> &picked, float nms_threshold)
{
    picked.clear();

    const int n = faceobjects.size();

    std::vector<float> areas(n);
    for (int i = 0; i < n; i++)
    {
        areas[i] = faceobjects[i].rect.width * faceobjects[i].rect.height;
    }

    for (int i = 0; i < n; i++)
    {
        const Object &a = faceobjects[i];

        int keep = 1;
        for (int j = 0; j < (int)picked.size(); j++)
        {
            const Object &b = faceobjects[picked[j]];

            // intersection over union
            float inter_area = intersection_area(a, b);
            float union_area = areas[i] + areas[picked[j]] - inter_area;
            // float IoU = inter_area / union_area
            if (inter_area / union_area > nms_threshold)
                keep = 0;
        }

        if (keep)
            picked.push_back(i);
    }
}
static void generate_grids_and_stride(const int target_w, const int target_h, std::vector<int> &strides, std::vector<GridAndStride> &grid_strides)
{
    for (int i = 0; i < (int)strides.size(); i++)
    {
        int stride = strides[i];
        int num_grid_w = target_w / stride;
        int num_grid_h = target_h / stride;
        for (int g1 = 0; g1 < num_grid_h; g1++)
        {
            for (int g0 = 0; g0 < num_grid_w; g0++)
            {
                GridAndStride gs;
                gs.grid0 = g0;
                gs.grid1 = g1;
                gs.stride = stride;
                grid_strides.push_back(gs);
            }
        }
    }
}
static void generate_proposals(std::vector<GridAndStride> grid_strides, const ncnn::Mat &pred, float prob_threshold, std::vector<Object> &objects)
{
    const int num_points = grid_strides.size();
    const int num_class = 10;
    const int reg_max_1 = 16;
    for (int i = 0; i < num_points; i++)
    {

        const float *scores = pred.row(i) + 4 * reg_max_1;
        // find label with max score
        int label = -1;
        float score = -FLT_MAX;
        for (int k = 0; k < num_class; k++)
        {
            float confidence = scores[k];
            if (confidence > score)
            {
                label = k;
                score = confidence;
            }
        }
        float box_prob = sigmoid(score);
        if (box_prob >= prob_threshold)
        {
            ncnn::Mat bbox_pred(reg_max_1, 4, (void *)pred.row(i));
            {
                ncnn::Layer *softmax = ncnn::create_layer("Softmax");

                ncnn::ParamDict pd;
                pd.set(0, 1); // axis
                pd.set(1, 1);
                softmax->load_param(pd);

                ncnn::Option opt;
                opt.num_threads = 1;
                opt.use_packing_layout = false;

                softmax->create_pipeline(opt);

                softmax->forward_inplace(bbox_pred, opt);

                softmax->destroy_pipeline(opt);

                delete softmax;
            }
            float pred_ltrb[4];
            for (int k = 0; k < 4; k++)
            {
                float dis = 0.f;
                const float *dis_after_sm = bbox_pred.row(k);
                for (int l = 0; l < reg_max_1; l++)
                {
                    dis += l * dis_after_sm[l];
                }

                pred_ltrb[k] = dis * grid_strides[i].stride;
            }
            float pb_cx = (grid_strides[i].grid0 + 0.5f) * grid_strides[i].stride;
            float pb_cy = (grid_strides[i].grid1 + 0.5f) * grid_strides[i].stride;

            float x0 = pb_cx - pred_ltrb[0];
            float y0 = pb_cy - pred_ltrb[1];
            float x1 = pb_cx + pred_ltrb[2];
            float y1 = pb_cy + pred_ltrb[3];
            Object obj;
            obj.rect.x = x0;
            obj.rect.y = y0;
            obj.rect.width = x1 - x0;
            obj.rect.height = y1 - y0;
            obj.label = label;
            obj.prob = box_prob;
            objects.push_back(obj);
        }
    }
}

char *generateWarning(const char *class_name)
{
    const std::string warn = "Chú ý!";
    std::string content = "";
    const std::string name = class_name;
    if (name == "Bicycle")
    {
        content = "Có người đi xe đạp phía trước!";
    }
    else if (name == "Bus")
    {
        content = "Có xe buýt phía trước!";
    }
    else if (name == "Car")
    {
        content = "Có xe hơi phía trước!";
    }
    else if (name == "Dog")
    {
        content = "Có chó phía trước!";
    }
    else if (name == "Electric pole")
    {
        content = "Có cột điện phía trước!";
    }
    else if (name == "Motorcycle")
    {
        content = "Có người đi xe máy phía trước!";
    }
    else if (name == "Person")
    {
        content = "Có người phía trước!";
    }
    else if (name == "Traffic signs")
    {
        content = "Có biển báo giao thông phía trước!";
    }
    else if (name == "Cây")
    {
        content = "Có cây phía trước!";
    }
    else if (name == "Uncovered manhole")
    {
        content = "Có cống hở phía trước!";
    }

    //char *warning = (warn + ", " + content).c_str();
    return (char *)(warn + ", " + content).c_str();
}


Yolo::Yolo()
{
    blob_pool_allocator.set_size_compare_ratio(0.f);
    workspace_pool_allocator.set_size_compare_ratio(0.f);
    cls = new Classifier();
}

int Yolo::load(AAssetManager *mgr, const char *modeltype, int _target_size, const float *_mean_vals, const float *_norm_vals, bool use_gpu)
{
    yolo.clear();
    blob_pool_allocator.clear();
    workspace_pool_allocator.clear();

    ncnn::set_cpu_powersave(2);
    ncnn::set_omp_num_threads(ncnn::get_big_cpu_count());

    yolo.opt = ncnn::Option();

#if NCNN_VULKAN
    yolo.opt.use_vulkan_compute = use_gpu;
#endif

    yolo.opt.num_threads = ncnn::get_big_cpu_count();
    yolo.opt.blob_allocator = &blob_pool_allocator;
    yolo.opt.workspace_allocator = &workspace_pool_allocator;

    char parampath[256];
    char modelpath[256];
    sprintf(parampath, "yolov8%s.param", modeltype);
    sprintf(modelpath, "yolov8%s.bin", modeltype);

    yolo.load_param(mgr, parampath);
    yolo.load_model(mgr, modelpath);

    target_size = _target_size;
    mean_vals[0] = _mean_vals[0];
    mean_vals[1] = _mean_vals[1];
    mean_vals[2] = _mean_vals[2];
    norm_vals[0] = _norm_vals[0];
    norm_vals[1] = _norm_vals[1];
    norm_vals[2] = _norm_vals[2];

    const float cls_norm_vals[][3] =
        {
            {1 / 2.f, 1 / 2.f, 1 / 2.f},
            {1 / 2.f, 1 / 2.f, 1 / 2.f},
        };
    cls->load(mgr, 128, cls_norm_vals[0], false);
    return 0;
}

int Yolo::detect(const cv::Mat &rgb, std::vector<Object> &objects, float prob_threshold, float nms_threshold)
{
    int width = rgb.cols;
    int height = rgb.rows;

    // pad to multiple of 32
    int w = width;
    int h = height;
    float scale = 1.f;
    if (w > h)
    {
        scale = (float)target_size / w;
        w = target_size;
        h = h * scale;
    }
    else
    {
        scale = (float)target_size / h;
        h = target_size;
        w = w * scale;
    }

    ncnn::Mat in = ncnn::Mat::from_pixels_resize(rgb.data, ncnn::Mat::PIXEL_RGB, width, height, w, h);

    // pad to target_size rectangle
    int wpad = (w + 31) / 32 * 32 - w;
    int hpad = (h + 31) / 32 * 32 - h;
    ncnn::Mat in_pad;
    ncnn::copy_make_border(in, in_pad, hpad / 2, hpad - hpad / 2, wpad / 2, wpad - wpad / 2, ncnn::BORDER_CONSTANT, 0.f);

    in_pad.substract_mean_normalize(0, norm_vals);

    ncnn::Extractor ex = yolo.create_extractor();

    ex.input("in0", in_pad);

    std::vector<Object> proposals;

    ncnn::Mat out;
    ex.extract("out0", out);
    std::vector<int> strides = {8, 16, 32}; // might have stride=64
    std::vector<GridAndStride> grid_strides;
    generate_grids_and_stride(in_pad.w, in_pad.h, strides, grid_strides);

    generate_proposals(grid_strides, out, prob_threshold, proposals);
    // sort all proposals by score from highest to lowest
    qsort_descent_inplace(proposals);
    // slicing(proposals, 5);
    //  apply nms with nms_threshold
    std::vector<int> picked;
    nms_sorted_bboxes(proposals, picked, nms_threshold);

    int count = picked.size();

    objects.resize(count);
    for (int i = 0; i < count; i++)
    {
        objects[i] = proposals[picked[i]];

        // adjust offset to original unpadded
        float x0 = (objects[i].rect.x - (wpad / 2)) / scale;
        float y0 = (objects[i].rect.y - (hpad / 2)) / scale;
        float x1 = (objects[i].rect.x + objects[i].rect.width - (wpad / 2)) / scale;
        float y1 = (objects[i].rect.y + objects[i].rect.height - (hpad / 2)) / scale;

        // clip
        x0 = std::max(std::min(x0, (float)(width - 1)), 0.f);
        y0 = std::max(std::min(y0, (float)(height - 1)), 0.f);
        x1 = std::max(std::min(x1, (float)(width - 1)), 0.f);
        y1 = std::max(std::min(y1, (float)(height - 1)), 0.f);

        objects[i].rect.x = x0;
        objects[i].rect.y = y0;
        objects[i].rect.width = x1 - x0;
        objects[i].rect.height = y1 - y0;
    }

    // sort objects by area
    struct
    {
        bool operator()(const Object &a, const Object &b) const
        {
            return a.rect.area() > b.rect.area();
        }
    } objects_area_greater;
    std::sort(objects.begin(), objects.end(), objects_area_greater);
    return 0;
}

char *Yolo::draw(cv::Mat &rgb, const std::vector<AgedObject> &objects, float prob_threshold)
{
    static const char *class_names[] = {
        "Bicycle",
        "Bus",
        "Car",
        "Dog",
        "Electric pole",
        "Motorcycle",
        "Person",
        "Traffic signs",
        "Tree",
        "Uncovered manhole"};
    static const unsigned char colors[10][3] = {
        {54, 67, 244},
        {99, 30, 233},
        {176, 39, 156},
        {183, 58, 103},
        {181, 81, 63},
        {243, 150, 33},
        {244, 169, 3},
        {212, 188, 0},
        {136, 150, 0},
        {80, 175, 76}};

    int color_index = 0;

    std::vector<std::string> signContents(objects.size(), "");

    for (size_t i = 0; i < objects.size(); i++)
    {
        if(objects[i].age != 0)
            continue;
        const Object &obj = objects[i].obj;
        //         fprintf(stderr, "%d = %.5f at %.2f %.2f %.2f x %.2f\n", obj.label, obj.prob,
        //                 obj.rect.x, obj.rect.y, obj.rect.width, obj.rect.height);
        const unsigned char *color = colors[color_index % 19];
        color_index++;

        cv::Scalar cc(color[0], color[1], color[2]);

        cv::rectangle(rgb, obj.rect, cc, 2);

        char text[256];
        if (obj.label != 7)
        {
            int width = rgb.cols;
            int height = rgb.rows;
            int x = int(obj.rect.x);
            int y = int(obj.rect.y);
            if(x< 0 || y < 0 || x + obj.rect.width > width || y + obj.rect.height > height)
                continue;
            cv::Mat in = rgb(cv::Rect(x,y,obj.rect.width, obj.rect.height));
            char label_sign[256];            
            float cls_score = cls->detect(in,label_sign,.7F);
            float final_score = cls_score * obj.prob;
            if (final_score < prob_threshold)
                continue;
            else
                sprintf(text, "Id: %zu %s %.1f%%", i,label_sign, final_score * 100);
        }
        else
            sprintf(text, "Id: %zu %s %.1f%%",i, class_names[obj.label], obj.prob * 100);
        int baseLine = 0;
        cv::Size label_size = cv::getTextSize(text, cv::FONT_HERSHEY_SIMPLEX, 0.5, 1, &baseLine);

        int x = obj.rect.x;
        int y = obj.rect.y - label_size.height - baseLine;
        if (y < 0)
            y = 0;
        if (x + label_size.width > rgb.cols)
            x = rgb.cols - label_size.width;

        cv::rectangle(rgb, cv::Rect(cv::Point(x, y), cv::Size(label_size.width, label_size.height + baseLine)), cc, -1);

        cv::Scalar textcc = (color[0] + color[1] + color[2] >= 381) ? cv::Scalar(0, 0, 0) : cv::Scalar(255, 255, 255);

        cv::putText(rgb, text, cv::Point(x, y + label_size.height), cv::FONT_HERSHEY_SIMPLEX, 0.5, textcc, 1);
    }
    // char *_text;
    if (objects.size() == 0)
    {
        return "Quân đần";
    }
    else
    {
        return generateWarning(class_names[objects[0].obj.label], signContents, 0);
        // return "There is object in camera";
    }
}

char *Yolo::generateWarning(char *class_name)
{
    const std::string warning = "Chú ý!";
    const std::string content = "";
    const std::string name = class_name;
    if (name == "Bicycle")
    {
        content = "Có người đi xe đạp phía trước!";
    }
    else if (name == "Bus")
    {
        content = "Có xe buýt phía trước!";
    }
    else if (name == "Car")
    {
        content = "Có xe hơi phía trước!";
    }
    else if (name == "Dog")
    {
        content = "Có chó phía trước!";
    }
    else if (name == "Electric pole")
    {
        content = "Có cột điện phía trước!";
    }
    else if (name == "Motorcycle")
    {
        content = "Có người đi xe máy phía trước!";
    }
    else if (name == "Person")
    {
        content = "Có người phía trước!";
    }
    else if (name == "Traffic signs")
    {
        content = "Có biển báo giao thông phía trước!";
    }
    else if (name == "Cây")
    {
        content = "Có cây phía trước!";
    }
    else if (name == "Uncovered manhole")
    {
        content = "Có cống hở phía trước!";
    }

    char *warning = (warning + ", " + content).c_str();
    return warning;
}

void Yolo::generateLabelSignWarning(std::vector<std::string> &signContents, char *sign_label, int index)
{
    const std::string label = sign_label;
    if (label == "DP.135")
    {
        signContents[index] = "Hết tất cả các lệnh cấm";
    }
    else if (label == "P.102")
    {
        signContents[index] = "Cấm đi ngược chiều";
    }
    else if (label == "P.103a")
    {
        signContents[index] = "Cấm xe ô tô";
    }
    else if (label == "P.103b")
    {
        signContents[index] = "Cấm ô tô rẽ phải";
    }
    else if (label == "P.103c")
    {
        signContents[index] = "Cấm ô tô rẽ trái";
    }
    else if (label == "P.104")
    {
        signContents[index] = "Cấm xe máy";
    }
    else if (label == "P.106a")
    {
        signContents[index] = "Cấm xe tải";
    }
    else if (label == "P.106b")
    {
        signContents[index] = "Cấm xe tải có khối lượng chuyên chở lớn hơn giá trị nhất định ghi trên biển số";
    }
    else if (label == "P.107a")
    {
        signContents[index] = "Cấm xe ô tô khách";
    }
    else if (label == "P.112")
    {
        signContents[index] = "Cấm người đi bộ";
    }
    else if (label == "P.115")
    {
        signContents[index] = "Hạn chế trọng tải toàn bộ xe";
    }
    else if (label == "P.117")
    {
        signContents[index] = "Hạn chế chiều cao";
    }
    else if (label == "P.123a")
    {
        signContents[index] = "Cấm rẽ trái";
    }
    else if (label == "P.123b")
    {
        signContents[index] = "Cấm rẽ phải";
    }
    else if (label == "P.124a")
    {
        signContents[index] = "Cấm quay đầu xe";
    }
    else if (label == "P.124b")
    {
        signContents[index] = "Cấm ô tô quay đầu xe";
    }
    else if (label == "P.124c")
    {
        signContents[index] = "Cấm rẽ trái và quay đầu xe";
    }
    else if (label == "P.125")
    {
        signContents[index] = "Cấm vượt";
    }
    else if (label == "P.127")
    {
        signContents[index] = "Tốc độ tối đa cho phép";
    }
    else if (label == "P.128")
    {
        signContents[index] = "Cấm sử dụng còi";
    }
    else if (label == "P.130")
    {
        signContents[index] = "Cấm dừng xe và đỗ xe";
    }
    else if (label == "P.131a")
    {
        signContents[index] = "Cấm đỗ xe";
    }
    else if (label == "P.137")
    {
        signContents[index] = "Cấm rẽ trái, cấm rẽ phải";
    }
    else if (label == "P.245a")
    {
        signContents[index] = "Cấm gì đó không biết";
    }
    else if (label == "R.301c")
    {
        signContents[index] = "Các xe chỉ được rẽ trái";
    }
    else if (label == "R.301d")
    {
        signContents[index] = "Các xe chỉ được rẽ phải";
    }
    else if (label == "R.301e")
    {
        signContents[index] = "Các xe chỉ được rẽ trái";
    }
    else if (label == "R.302a")
    {
        signContents[index] = "Hướng phải đi vòng chướng ngại vật sang phải";
    }
    else if (label == "R.302b")
    {
        signContents[index] = "Hướng phải đi vòng chướng ngại vật sang trái";
    }
    else if (label == "R.303")
    {
        signContents[index] = "Nơi giao nhau chạy theo vòng xuyến";
    }
    else if (label == "R.407a")
    {
        signContents[index] = "Đường một chiều";
    }
    else if (label == "R.409")
    {
        signContents[index] = "Chỗ quay xe";
    }
    else if (label == "R.425")
    {
        signContents[index] = "Bệnh viện";
    }
    else if (label == "R.434")
    {
        signContents[index] = "Bến xe buýt";
    }
    else if (label == "S.509a")
    {
        signContents[index] = "Chiều cao an toàn";
    }
    else if (label == "W.201a")
    {
        signContents[index] = "Chỗ ngoặt nguy hiểm vòng bên trái";
    }
    else if (label == "W.201b")
    {
        signContents[index] = "Chỗ ngoặt nguy hiểm vòng bên phải";
    }
    else if (label == "W.202a")
    {
        signContents[index] = "Chỗ ngoặt nguy hiểm vòng bên trái";
    }
    else if (label == "W.202b")
    {
        signContents[index] = "Chỗ ngoặt nguy hiểm vòng bên phải";
    }
    else if (label == "W.203b")
    {
        signContents[index] = "Đường bị hẹp về phía trái";
    }
    else if (label == "W.203c")
    {
        signContents[index] = "Đường bị hẹp về phía phải";
    }
    else if (label == "W.205a")
    {
        signContents[index] = "Đường giao nhau";
    }
    else if (label == "W.205b")
    {
        signContents[index] = "Đường giao nhau có nhánh bên phải";
    }
    else if (label == "W.205d")
    {
        signContents[index] = "Đường giao nhau dạng chữ T";
    }
    else if (label == "W.207a")
    {
        signContents[index] = "Giao nhau với đường không ưu tiên";
    }
    else if (label == "W.207b")
    {
        signContents[index] = "Giao nhau với đường không ưu tiên";
    }
    else if (label == "W.207c")
    {
        signContents[index] = "Giao nhau với đường không ưu tiên";
    }
    else if (label == "W.208")
    {
        signContents[index] = "Giao nhau với đường ưu tiên";
    }
    else if (label == "W.209")
    {
        signContents[index] = "Giao nhau có tín hiệu đèn";
    }
    else if (label == "W.210")
    {
        signContents[index] = "Giao nhau với đường sắt có rào chắn";
    }
    else if (label == "W.219")
    {
        signContents[index] = "Dốc xuống nguy hiểm";
    }
    else if (label == "W.221b")
    {
        signContents[index] = "Đường không bằng phẳng";
    }
    else if (label == "W.224")
    {
        signContents[index] = "Đường không bằng phẳng";
    }
    else if (label == "W.225")
    {
        signContents[index] = "Đường người đi bộ cắt ngang";
    }
    else if (label == "W.227")
    {
        signContents[index] = "Công trường";
    }
    else if (label == "W.233")
    {
        signContents[index] = "Nguy hiểm khác";
    }
    else if (label == "W.235")
    {
        signContents[index] = "Đường đôi";
    }
    else if (label == "W.245")
    {
        signContents[index] = "Đi chậm";
    }
    else
    {
        signContents[index] = "Không nhận điện được biển báo";
    }
}