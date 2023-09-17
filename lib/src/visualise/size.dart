class Size {
  Size(this.width, this.height);
  Size.copyFrom(Size pageSize)
      : width = pageSize.width,
        height = pageSize.height;
  int width;
  int height;
}
