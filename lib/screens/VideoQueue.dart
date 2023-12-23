import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:do_an_1/screens/ErrorScreen.dart';
import 'package:do_an_1/utils/utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:share_plus/share_plus.dart';

class VideoQueue extends StatefulWidget {
  const VideoQueue({Key? key}) : super(key: key);

  @override
  _VideoQueueState createState() => _VideoQueueState();
}

class _VideoQueueState extends State<VideoQueue> {
  var db = FirebaseFirestore.instance;
  double offset1 = 0.0;
  double offset2 = 0.0;
  Future<List<dynamic>>? artifactList = null;
  VideoPlayerController? controller = null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      artifactList = _initArtifact();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        _buildArtifactGridView(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(
              0, MediaQuery.of(context).size.height - offset1, 0.0),
          child: DragTarget(
            builder: (context, candidateData, rejectedData) => Container(
                height: 200,
                width: MediaQuery.of(context).size.width / 2,
                decoration: const BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20))),
                child: const Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: Icon(
                        size: 30.0,
                        Icons.delete,
                        color: Colors.white,
                      )),
                )),
            onMove: (details) {
              offset1 = 80;
              setState(() {});
            },
            onLeave: (data) {
              offset1 = 50;
              setState(() {});
            },
            onAccept: (data) => showDialog(
                context: context,
                builder: (context) => AlertDialog(
                      title: const Text('Warning'),
                      content: const Text(
                        'This action will delete this artifact forever. Are you sure you want to do this',
                        style: TextStyle(fontSize: 15),
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'No'),
                          child: const Text(
                            'No',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _handleDeleteArtifacts(data!);
                            Navigator.pop(context, "Yes");
                            setState(() {});
                          },
                          child: const Text(
                            'Yes',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    )),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(
              MediaQuery.of(context).size.width / 2,
              MediaQuery.of(context).size.height - offset2,
              0.0),
          child: DragTarget(
            builder: (context, candidateData, rejectedData) => Container(
                height: 200,
                width: MediaQuery.of(context).size.width / 2,
                decoration: const BoxDecoration(
                    color: Color(0xff5CE3AB),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20))),
                child: const Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: Icon(
                        size: 30.0,
                        Icons.share,
                        color: Colors.white,
                      )),
                )),
            onMove: (details) {
              offset2 = 80;
              setState(() {});
            },
            onLeave: (data) {
              offset2 = 50;
              setState(() {});
            },
            onAccept: (data) => _handleSharedButton(data!),
          ),
        )
      ],
    ));
  }

  Widget _buildArtifactGridView() {
    return artifactList == null
        ? const Center(child: CircularProgressIndicator())
        : FutureBuilder<List<dynamic>>(
            future: artifactList,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                debugPrint(snapshot.data.toString());
                if (snapshot.data!.isEmpty) {
                  return Center(
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "You dont have and video infereced.",
                        style: TextStyle(fontSize: 15),
                      ),
                      const Text(
                        "Click button below to start detect object in video",
                        style: TextStyle(fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                      ElevatedButton(
                          onPressed: () async =>
                              await routing(context, "VideoDetection"),
                          child: const Text(
                            "Get started",
                            style: TextStyle(fontSize: 15),
                          ))
                    ],
                  ));
                }
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 170.0,
                      mainAxisSpacing: 10.0,
                      crossAxisSpacing: 10.0,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (context, index) {
                      var videoCard = _buildVideoCard(
                          context, index, snapshot.data![index].toString());
                      return FutureBuilder<Widget>(
                          future: videoCard,
                          builder: (context, snapshot) => snapshot.hasData
                              ? snapshot.data!
                              : const Column(
                                  children: [
                                    Card(
                                      child: SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: Center(
                                              child: SizedBox(
                                                  width: 30,
                                                  height: 30,
                                                  child:
                                                      CircularProgressIndicator()))),
                                    ),
                                    Text("loading..")
                                  ],
                                ));
                    },
                    itemCount: snapshot.data!.length,
                  ),
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            });
  }

  Future<Widget> _buildVideoCard(
      BuildContext context, int index, String artifactId) async {
    var artifact =
        await db.collection("artifacts").doc(artifactId.split("/")[1]).get();
    if (artifact.exists) {
      String path = "";
      path = artifact.data()!["thumbnailURL"];
      return LongPressDraggable(
        data: artifact.id,
        onDragStarted: () {
          offset1 = 50.0;
          offset2 = 50.0;
          setState(() {});
        },
        onDragEnd: (detail) {
          offset1 = 0.0;
          offset2 = 0.0;
          setState(() {});
        },
        feedback: SizedBox(
            width: 100,
            height: 100,
            child: path != ""
                ? Card(child: Image.network(path))
                : const Card(child: Icon(size: 40, Icons.downloading))),
        child: InkWell(
          onTap: () async {
            controller = VideoPlayerController.networkUrl(
                Uri.parse(artifact.data()!['path']));
            await showDialog(
              context: context,
              builder: (context) => Center(
                child: FutureBuilder<void>(
                  future: controller!
                      .initialize()
                      .then((value) => controller!.play()),
                  builder: (context, snapshot) =>
                      snapshot.connectionState == ConnectionState.done
                          ? AspectRatio(
                              aspectRatio: controller!.value.aspectRatio,
                              child: VideoPlayer(controller!))
                          : const CircularProgressIndicator(),
                ),
              ),
            );
          },
          child: Column(
            children: [
              Card(
                child: SizedBox(
                    width: 100,
                    height: 100,
                    child: path != ""
                        ? Image.network(
                            path,
                            fit: BoxFit.contain,
                          )
                        : const Icon(size: 40, Icons.downloading)),
              ),
              Text(artifact.data()!["name"])
            ],
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Future<List<dynamic>> _initArtifact() async {
    return db
        .collection("user")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get()
        .then((value) {
      if (value.data() != null) {
        return value.data()!["artifacts"] as List<dynamic>;
      } else {
        return List<Map<String, dynamic>>.empty();
      }
    }).catchError((error) async {
      debugPrint(error.toString());
      await Navigator.of(this.context)
          .push(MaterialPageRoute(builder: (context) => const ErrorScreen()));
    });
  }

  _handleDeleteArtifacts(Object data) async {
    var message = " Successfully delete the artifact";
    await db
        .collection("user")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .update({
      "artifacts": FieldValue.arrayRemove(["artifacts/$data"])
    }).catchError((error) {
      debugPrint(error.toString());
    });
    Fluttertoast.showToast(msg: message, toastLength: Toast.LENGTH_SHORT);
  }

  _handleSharedButton(Object videoPath) async {
    var link =
        (await db.collection("artifacts").doc(videoPath.toString()).get())
            .data()!["path"];
    if (link != "") {
      Share.shareUri(Uri.parse(link));
    } else {
      Fluttertoast.showToast(msg: "This video hasn't been inferenced");
    }
  }
}
