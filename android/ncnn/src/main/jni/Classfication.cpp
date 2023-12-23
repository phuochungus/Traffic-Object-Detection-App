#include "Classfication.h"
#include "log.h"
#include <opencv2/core/core.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include "cpu.h"
#include <string.h>

float generateLabel(ncnn::Mat &predict, char *text, float prob_threshold)
{
    static const char *class_names[] = {
        "DP.135",
        "P.102",
        "P.103a",
        "P.103b",
        "P.103c",
        "P.104",
        "P.106a",
        "P.106b",
        "P.107a",
        "P.112",
        "P.115",
        "P.117",
        "P.123a",
        "P.123b",
        "P.124a",
        "P.124b",
        "P.124c",
        "P.125",
        "P.127",
        "P.128",
        "P.130",
        "P.131a",
        "P.137",
        "P.245a",
        "R.301c",
        "R.301d",
        "R.301e",
        "R.302a",
        "R.302b",
        "R.303",
        "R.407a",
        "R.409",
        "R.425",
        "R.434",
        "S.509a",
        "W.201a",
        "W.201b",
        "W.202a",
        "W.202b",
        "W.203b",
        "W.203c",
        "W.205a",
        "W.205b",
        "W.205d",
        "W.207a",
        "W.207b",
        "W.207c",
        "W.208",
        "W.209",
        "W.210",
        "W.219",
        "W.221b",
        "W.224",
        "W.225",
        "W.227",
        "W.233",
        "W.235",
        "W.245",
    };
    // Softmax to get propability
    ncnn::Layer *softmax = ncnn::create_layer("Softmax");

    ncnn::ParamDict pd;
    pd.set(0, 0); // axis
    pd.set(1, 1);
    softmax->load_param(pd);

    ncnn::Option opt;
    opt.num_threads = 1;
    opt.use_packing_layout = false;

    softmax->create_pipeline(opt);

    softmax->forward_inplace(predict, opt);

    softmax->destroy_pipeline(opt);

    delete softmax;
    // // Flatten predict Mat to vector
    ncnn::Mat predict_flatterned = predict.reshape(predict.w * predict.h * predict.c);
    std::vector<float> scores;
    scores.resize(predict_flatterned.w);
    for (int j = 0; j < predict_flatterned.w; j++)
    {
        scores[j] = predict_flatterned[j];
    }
    // get the most confident label
    int label = -1;
    float score = -FLT_MAX;
    int num_class = int(scores.size());
    for (int k = 0; k < num_class; k++)
    {
        float confidence = scores[k];
        if (confidence > score)
        {
            label = k;
            score = confidence;
        }
    }
    //Print label
    sprintf(text, "%s", class_names[label]);
    return score;
}

Classifier::Classifier()
{
    blob_pool_allocator.set_size_compare_ratio(0.f);
    workspace_pool_allocator.set_size_compare_ratio(0.f);
}

int Classifier::load(const char *modeltype, int target_size, const float *mean_vals, const float *norm_vals, bool use_gpu)
{
    return 0;
}

int Classifier::load(AAssetManager *mgr, int _target_size, const float *_norm_vals, bool use_gpu)
{
    classifier.clear();
    blob_pool_allocator.clear();
    workspace_pool_allocator.clear();
    ncnn::set_cpu_powersave(2);
    ncnn::set_omp_num_threads(ncnn::get_big_cpu_count());

    classifier.opt = ncnn::Option();
#if NCNN_VULKAN
    classifier.opt.use_vulkan_compute = use_gpu;
#endif
    classifier.opt.num_threads = ncnn::get_big_cpu_count();
    classifier.opt.blob_allocator = &blob_pool_allocator;
    classifier.opt.workspace_allocator = &workspace_pool_allocator;

    char parampath[256];
    char modelpath[256];
    sprintf(parampath, "classifier.param");
    sprintf(modelpath, "classifier.bin");

    classifier.load_param(mgr, parampath);
    classifier.load_model(mgr, modelpath);

    target_size = _target_size;
    norm_vals[0] = _norm_vals[0];
    norm_vals[1] = _norm_vals[1];
    norm_vals[2] = _norm_vals[2];
    return 0;
}

int Classifier::detect(cv::Mat &rgb, char *text, float prob_threshold)
{
    int width = rgb.cols;
    int height = rgb.rows;
    ncnn::Mat in_pad = ncnn::Mat::from_pixels_resize(rgb.data, ncnn::Mat::PIXEL_RGB, width, height, target_size, target_size);
    in_pad.substract_mean_normalize(0, norm_vals);
    ncnn::Extractor ex = classifier.create_extractor();
    ex.input("in0", in_pad);

    ncnn::Mat out;
    ex.extract("out0", out);
    float score = generateLabel(out, text, prob_threshold);
    if(score < prob_threshold)
        return 0.0;
    else
        return score;
}
