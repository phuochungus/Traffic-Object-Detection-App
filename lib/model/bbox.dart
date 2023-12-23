class BBox {
  double x = 0;
  double y = 0;
  double width = 0;
  double height = 0;
  String label = "";
  double accuracy = 0.0;

  BBox(this.x, this.y, this.width, this.height, this.label, this.accuracy);
  factory BBox.fromJson(Map<String, dynamic> json) {
    return BBox(
        double.parse(json['x'].toString()),
        double.parse(json['y'].toString()),
        double.parse(json['width'].toString()),
        double.parse(json['height'].toString()),
        json['lable'].toString(),
        double.parse(json['accuracy'].toString()));
  }
}
