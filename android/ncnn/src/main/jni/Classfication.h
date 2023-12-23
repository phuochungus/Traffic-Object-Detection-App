#include <opencv2/core/core.hpp>

#include <net.h>

class Classifier
{
public:
    Classifier();
    int load(const char* modeltype, int target_size, const float* mean_vals, const float* norm_vals, bool use_gpu = false);

    int load(AAssetManager* mgr, int _target_size, const float* _norm_vals, bool use_gpu = false);

    int detect(cv::Mat& rgb, char *text,float prob_threshold = 0.4f);

private:
    int target_size;
    ncnn::Net classifier;
    float norm_vals[3];
    ncnn::UnlockedPoolAllocator blob_pool_allocator;
    ncnn::PoolAllocator workspace_pool_allocator;
};