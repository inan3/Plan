// lib/widgets/animated_icon_add.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AnimatedIconAdd extends StatefulWidget {
  final double effectiveIconSize;
  final String asset;
  final VoidCallback onTap;
  final bool isSelected;

  const AnimatedIconAdd({
    Key? key,
    required this.effectiveIconSize,
    required this.asset,
    required this.onTap,
    required this.isSelected,
  }) : super(key: key);

  @override
  _AnimatedIconAddState createState() => _AnimatedIconAddState();
}

class _AnimatedIconAddState extends State<AnimatedIconAdd>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState(){
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.effectiveIconSize)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose(){
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(){
    // Reinicia la animación desde 0.
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Icono base en color blanco (sin animación)
          SvgPicture.asset(
            widget.asset,
            color: Colors.white,
            width: widget.effectiveIconSize,
            height: widget.effectiveIconSize,
          ),
          // Icono en azul recortado por un círculo cuyo radio se anima
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return ClipPath(
                clipper: _CircleClipper(radius: _animation.value),
                child: SvgPicture.asset(
                  widget.asset,
                  color: Colors.blue,
                  width: widget.effectiveIconSize,
                  height: widget.effectiveIconSize,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  final double radius;

  _CircleClipper({required this.radius});

  @override
  Path getClip(Size size) {
    final Offset center = size.center(Offset.zero);
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_CircleClipper oldClipper) {
    return oldClipper.radius != radius;
  }
}
