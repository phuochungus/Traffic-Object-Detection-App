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

#include <android/asset_manager_jni.h>
#include <android/native_window_jni.h>
#include <android/native_window.h>

#include <android/log.h>

#include <jni.h>

#include <string>
#include <vector>

#include <platform.h>
#include <benchmark.h>
#include <jni.h>
#include "yolo.h"
#include "log.h"
#include "ndkcamera.h"
#include <math.h>
#include <opencv2/core/core.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#if __ARM_NEON
#include <arm_neon.h>
#endif // __ARM_NEON

bool remove_and_age(AgedObject obj)
{
    if (obj.age >= 10)
        return true;
    else
        return false;
}
static int draw_unsupported(cv::Mat &rgb)
{
    const char text[] = "unsupported";

    int baseLine = 0;
    cv::Size label_size = cv::getTextSize(text, cv::FONT_HERSHEY_SIMPLEX, 1.0, 1, &baseLine);

    int y = (rgb.rows - label_size.height) / 2;
    int x = (rgb.cols - label_size.width) / 2;

    cv::rectangle(rgb, cv::Rect(cv::Point(x, y), cv::Size(label_size.width, label_size.height + baseLine)),
                  cv::Scalar(255, 255, 255), -1);

    cv::putText(rgb, text, cv::Point(x, y + label_size.height),
                cv::FONT_HERSHEY_SIMPLEX, 1.0, cv::Scalar(0, 0, 0));

    return 0;
}

static int draw_fps(cv::Mat &rgb)
{
    // resolve moving average
    float avg_fps = 0.f;
    {
        static double t0 = 0.f;
        static float fps_history[10] = {0.f};

        double t1 = ncnn::get_current_time();
        if (t0 == 0.f)
        {
            t0 = t1;
            return 0;
        }

        float fps = 1000.f / (t1 - t0);
        t0 = t1;

        for (int i = 9; i >= 1; i--)
        {
            fps_history[i] = fps_history[i - 1];
        }
        fps_history[0] = fps;

        if (fps_history[9] == 0.f)
        {
            return 0;
        }

        for (int i = 0; i < 10; i++)
        {
            avg_fps += fps_history[i];
        }
        avg_fps /= 10.f;
    }

    char text[32];
    sprintf(text, "FPS=%.2f", avg_fps);

    int baseLine = 0;
    cv::Size label_size = cv::getTextSize(text, cv::FONT_HERSHEY_SIMPLEX, 0.5, 1, &baseLine);

    int y = 0;
    int x = rgb.cols - label_size.width;

    cv::rectangle(rgb, cv::Rect(cv::Point(x, y), cv::Size(label_size.width, label_size.height + baseLine)),
                  cv::Scalar(255, 255, 255), -1);

    cv::putText(rgb, text, cv::Point(x, y + label_size.height),
                cv::FONT_HERSHEY_SIMPLEX, 0.5, cv::Scalar(0, 0, 0));

    return 0;
}

static Yolo *g_yolo = 0;
static ncnn::Mutex lock;

class MyNdkCamera : public NdkCameraWindow
{
public:
    virtual void on_image_render(cv::Mat &rgb) const;
    void set_javaVM(JavaVM *env);
    void set_jobject(jobject _obj);
    void set_interval(int obj);
    static int interval;
    static JavaVM *jvm;
    static jclass clazz;
    static jobject object;
    static std::vector<AgedObject> current_objects;

private:
};
int MyNdkCamera::interval = 60;
JavaVM *MyNdkCamera::jvm = nullptr;
jclass MyNdkCamera::clazz = NULL;
jobject MyNdkCamera::object = NULL;
std::vector<AgedObject> MyNdkCamera::current_objects = std::vector<AgedObject>();
void generateObjectList(std::vector<Object> &objects)
{
    int old_size = MyNdkCamera::current_objects.size();
    int new_size = objects.size();
    std::vector<float> result(old_size, FLT_MAX);
    std::vector<int> indexList(old_size, -1);
    std::vector<bool> usedList(new_size, false);
    // find min score for all object in old_object array
    for (int i = 0; i < old_size; i++)
    {
        float min = FLT_MAX;
        int ind = -1;
        for (int j = 0; j < new_size; j++)
        {
            Object oldObj = MyNdkCamera::current_objects[i].obj;
            Object newObj = objects[j];
            // Center point new object
            cv::Rect2f rect1 = newObj.rect;
            cv::Point p1(rect1.x + newObj.rect.width / 2, rect1.y + newObj.rect.height / 2);
            // Center point old object
            cv::Rect2f rect2 = oldObj.rect;
            cv::Point p2(rect2.x + oldObj.rect.width / 2, rect2.y + oldObj.rect.height / 2);

            float score = cv::norm(p1 - p2);
            if (score < min && oldObj.label == newObj.label)
            {
                min = score;
                ind = j;
            }
        }
        if (min < result[i])
        {
            result[i] = min;
            usedList[indexList[i]] = false;
            usedList[ind] = true;
            indexList[i] = ind;
            MyNdkCamera::current_objects[i].age = -1;
        }
    }
    std::remove_if(MyNdkCamera::current_objects.begin(), MyNdkCamera::current_objects.end(), remove_and_age);
    for (int i = 0; i < MyNdkCamera::current_objects.size(); i++)
        if (indexList[i] != -1)
        {
            MyNdkCamera::current_objects[i].obj.rect = objects[indexList[i]].rect;
            MyNdkCamera::current_objects[i].obj.prob = objects[indexList[i]].prob;
        }
        else
            MyNdkCamera::current_objects[i].age += 1;
    for (int i = 0; i < usedList.size(); i++)
    {
        if (!usedList[i])
        {
            AgedObject obj;
            obj.obj = objects[i];
            obj.age = 0;
            MyNdkCamera::current_objects.insert(MyNdkCamera::current_objects.end(), obj);
        }
    }
}
void MyNdkCamera::set_interval(int obj)
{
    interval = 60;
}
void MyNdkCamera::on_image_render(cv::Mat &rgb) const
{
    // nanodet
    {
        ncnn::MutexLockGuard g(lock);

        if (g_yolo)
        {
            int old_size = MyNdkCamera::current_objects.size();
            std::vector<Object> objects;
            g_yolo->detect(rgb, objects);
            int width = objects.size();
            int height = MyNdkCamera::current_objects.size();
            generateObjectList(objects);
            char *temp = g_yolo->draw(rgb, MyNdkCamera::current_objects);
            if (old_size != MyNdkCamera::current_objects.size() && jvm != nullptr && MyNdkCamera::object != NULL)
            {
                JNIEnv *env;
                JavaVMAttachArgs args;
                args.version = JNI_VERSION_1_4; // choose your JNI version
                args.name = NULL;               // you might want to give thse java thread a name
                args.group = NULL;              // you might want to assign the java thread to a ThreadGroup
                jvm->AttachCurrentThread(&env, &args);
                jstring jstr = env->NewStringUTF(temp);
                jmethodID speak = env->GetMethodID(clazz, "Speak", "(Ljava/lang/String;)V");
                env->CallVoidMethod(MyNdkCamera::object, speak, jstr);
            }
        }
        else
        {
            draw_unsupported(rgb);
        }
    }
    draw_fps(rgb);
}

static MyNdkCamera *g_camera = 0;

extern "C"
{

    JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved)
    {
        __android_log_print(ANDROID_LOG_DEBUG, "ncnn", "JNI_OnLoad");

        g_camera = new MyNdkCamera;
        return JNI_VERSION_1_4;
    }

    JNIEXPORT void JNI_OnUnload(JavaVM *vm, void *reserved)
    {
        __android_log_print(ANDROID_LOG_DEBUG, "ncnn", "JNI_OnUnload");

        {
            ncnn::MutexLockGuard g(lock);

            delete g_yolo;
            g_yolo = 0;
        }

        delete g_camera;
        g_camera = 0;
    }

    // public native boolean loadModel(AssetManager mgr, int modelid, int cpugpu);
    JNIEXPORT jboolean JNICALL Java_com_tencent_yolov8ncnn_Yolov8Ncnn_loadModel(JNIEnv *env, jobject thiz, jobject assetManager, jint modelid, jint cpugpu)
    {
        if (modelid < 0 || modelid > 6 || cpugpu < 0 || cpugpu > 1)
        {
            return JNI_FALSE;
        }

        AAssetManager *mgr = AAssetManager_fromJava(env, assetManager);

        __android_log_print(ANDROID_LOG_DEBUG, "ncnn", "loadModel %p", mgr);

        const char *modeltypes[] =
            {
                "n",
                "s",
            };

        const int target_sizes[] =
            {
                320,
                320,
            };

        const float mean_vals[][3] =
            {
                {103.53f, 116.28f, 123.675f},
                {103.53f, 116.28f, 123.675f},
            };

        const float norm_vals[][3] =
            {
                {1 / 255.f, 1 / 255.f, 1 / 255.f},
                {1 / 255.f, 1 / 255.f, 1 / 255.f},
            };

        const char *modeltype = modeltypes[(int)modelid];
        int target_size = target_sizes[(int)modelid];
        bool use_gpu = (int)cpugpu == 1;

        // reload
        {
            ncnn::MutexLockGuard g(lock);

            if (use_gpu && ncnn::get_gpu_count() == 0)
            {
                // no gpu
                delete g_yolo;
                g_yolo = 0;
            }
            else
            {
                if (!g_yolo)
                    g_yolo = new Yolo;
                g_yolo->load(mgr, modeltype, target_size, mean_vals[(int)modelid], norm_vals[(int)modelid], use_gpu);
            }
        }
        return JNI_TRUE;
    }

    // public native boolean openCamera(int facing);
    JNIEXPORT jboolean JNICALL Java_com_tencent_yolov8ncnn_Yolov8Ncnn_openCamera(JNIEnv *env, jobject thiz, jint facing)
    {
        if (facing < 0 || facing > 1)
            return JNI_FALSE;

        __android_log_print(ANDROID_LOG_DEBUG, "ncnn", "openCamera %d", facing);
        env->GetJavaVM(&MyNdkCamera::jvm);
        jclass clazzID = env->FindClass("com/tencent/yolov8ncnn/Yolov8Ncnn");
        if (MyNdkCamera::clazz == NULL)
            LOGD("NULL CLASS");
        else
        {
            LOGD("SAVE CLASS");
        }
        MyNdkCamera::clazz = reinterpret_cast<jclass>(env->NewGlobalRef(clazzID));
        // Set jobject as newGlobalRef
        MyNdkCamera::object = reinterpret_cast<jobject>(env->NewGlobalRef(thiz));
        // JavaVMOption* options = new JavaVMOption[1]; //holds various JVM optional settings
        // options[0].optionString = const_cast<char*>("-Djava.class.path="USER_CLASSPATH);
        // MyNdkCamera::jvm->options = options;

        g_camera->open((int)facing);
        return JNI_TRUE;
    }

    // public native boolean closeCamera();
    JNIEXPORT jboolean JNICALL Java_com_tencent_yolov8ncnn_Yolov8Ncnn_closeCamera(JNIEnv *env, jobject thiz)
    {
        __android_log_print(ANDROID_LOG_DEBUG, "ncnn", "closeCamera");

        g_camera->close();

        return JNI_TRUE;
    }

    // public native boolean setOutputWindow(Surface surface);
    JNIEXPORT jboolean JNICALL Java_com_tencent_yolov8ncnn_Yolov8Ncnn_setOutputWindow(JNIEnv *env, jobject thiz, jobject surface)
    {
        ANativeWindow *win = ANativeWindow_fromSurface(env, surface);

        __android_log_print(ANDROID_LOG_DEBUG, "ncnn", "setOutputWindow %p", win);

        g_camera->set_window(win);

        return JNI_TRUE;
    }
}
