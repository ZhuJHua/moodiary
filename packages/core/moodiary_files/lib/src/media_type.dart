enum MediaType {
  image(0, 'image'),
  audio(1, 'audio'),
  video(2, 'video'),
  file(3, 'file');

  const MediaType(this.number, this.value);

  final int number;
  final String value;

  static MediaType getType(int number) =>
      MediaType.values.firstWhere((e) => e.number == number);

  static MediaType getTypeFromValue(String value) {
    final mediaType = switch (value) {
      'image' => MediaType.image,
      'audio' => MediaType.audio,
      'video' => MediaType.video,
      'file' => MediaType.file,
      'thumbnail' => MediaType.video,
      _ => throw UnimplementedError('Unknown media type: $value'),
    };
    return mediaType;
  }
}
