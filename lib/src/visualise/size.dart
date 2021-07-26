class Size {
  int width;
  int height;
  Size(this.width, this.height);
  Size.copyFrom(Size pageSize)
      : width = pageSize.width,
        height = pageSize.height;
}
