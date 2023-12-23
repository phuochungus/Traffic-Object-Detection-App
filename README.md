# Installation Guide

## Prerequisites

Before you begin, ensure you have the following installed on your system:

1. **Android Studio:** Download and install Android Studio from [https://developer.android.com/studio](https://developer.android.com/studio).
2. **Java Development Kit (JDK):** Download and install the JDK from [https://docs.oracle.com/en/java/javase/11/install/overview-jdk-installation.html](https://docs.oracle.com/en/java/javase/11/install/overview-jdk-installation.html).
3. **CMake:** Download and install CMake from [https://cmake.org/download/](https://cmake.org/download/).
4. **Flutter:** Download and install Flutter from [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install).

## Installing the Android App

1. **Clone the repository:** Clone the repository containing the Android app to your local machine.

2. **Set up the Flutter project:** Open the project iin Android Studio or Visual Studio Code.

3. **Build the native code:** The process for building the native code differs depending on whether you're using Visual Studio Code or Android Studio.

### Using Visual Studio Code

1. Open the project directory in Visual Studio Code.
2. Open the command palette (Ctrl+Shift+P or Cmd+Shift+P).
3. Type "flutter run lib/main.dart" and press Enter.

### Using Android Studio

1. Open the project in Android Studio.
2. Navigate to **Build > Build Options**.
3. Select **Build and Run**.
4. Click **Apply** and then **Close**.
5. Click the **Run** button in the toolbar.

Once the native code has been built, you can run the Android app.


4. **Run the Android app:** Run the Android app in Android Studio.

## Troubleshooting

If you encounter any issues during the installation process, please refer to the following resources:

* **Android Studio documentation:** [https://developer.android.com/docs](https://developer.android.com/docs)
* **Flutter documentation:** [https://docs.flutter.dev/](https://docs.flutter.dev/)
* **Ncnn documentation:** [https://github.com/Tencent/ncnn](https://github.com/Tencent/ncnn)
or create and issue on this repository

## Additional Notes

* The app requires a minimum SDK version of 24.
* The app uses Cmake to build the native code, JNI to connect the native code to the Flutter code, and ncnn for image processing.
