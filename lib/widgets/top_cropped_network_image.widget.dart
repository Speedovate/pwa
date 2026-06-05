import 'package:flutter/material.dart';

class TopCroppedNetworkImage extends StatefulWidget {
  final ImageProvider imageProvider;
  final double visibleFraction;
  final Widget loadingChild;
  final Widget errorChild;

  const TopCroppedNetworkImage({
    required this.imageProvider,
    required this.visibleFraction,
    required this.loadingChild,
    required this.errorChild,
    super.key,
  });

  @override
  State<TopCroppedNetworkImage> createState() =>
      _TopCroppedNetworkImageState();
}

class _TopCroppedNetworkImageState extends State<TopCroppedNetworkImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  bool _isLoaded = false;
  bool _hasError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant TopCroppedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider ||
        oldWidget.visibleFraction != widget.visibleFraction) {
      _resolveImage();
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _removeImageListener() {
    final listener = _imageStreamListener;
    final stream = _imageStream;
    if (listener != null && stream != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  void _resolveImage() {
    _removeImageListener();
    _isLoaded = false;
    _hasError = false;

    final stream = widget.imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    final listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoaded = true;
          _hasError = false;
        });
      },
      onError: (exception, stackTrace) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoaded = false;
          _hasError = true;
        });
      },
    );

    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expandedHeight = constraints.maxHeight / widget.visibleFraction;
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isLoaded && !_hasError)
                ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minWidth: constraints.maxWidth,
                    maxWidth: constraints.maxWidth,
                    minHeight: expandedHeight,
                    maxHeight: expandedHeight,
                    child: Image(
                      image: widget.imageProvider,
                      width: constraints.maxWidth,
                      height: expandedHeight,
                      alignment: Alignment.topCenter,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else if (_hasError)
                widget.errorChild
              else
                Center(
                  child: widget.loadingChild,
                ),
            ],
          ),
        );
      },
    );
  }
}
