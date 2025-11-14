import 'package:flutter/material.dart';
import 'dart:async';

class CustomDateSpinnerWheel extends StatefulWidget {
  final List<String> items;
  final String initialValue;
  final ValueChanged<String> onSelectedItemChanged;
  final double itemExtent;
  final double pixelsPerScrollUnit; // How many pixels scrolled correspond to one item change
  final FixedExtentScrollController? scrollController; // Optional: if external control is needed

  const CustomDateSpinnerWheel({
    Key? key,
    required this.items,
    required this.initialValue,
    required this.onSelectedItemChanged,
    this.itemExtent = 40.0,
    this.pixelsPerScrollUnit = 30.0, // Default, can be tuned
    this.scrollController,
  }) : super(key: key);

  @override
  _CustomDateSpinnerWheelState createState() => _CustomDateSpinnerWheelState();
}

class _CustomDateSpinnerWheelState extends State<CustomDateSpinnerWheel> {
  late FixedExtentScrollController _controller;
  late int _currentIndex;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.items.indexOf(widget.initialValue);
    if (_currentIndex == -1) {
      _currentIndex = 0; // Default to first if not found
    }
    _controller = widget.scrollController ?? FixedExtentScrollController(initialItem: _currentIndex);
  }

  @override
  void didUpdateWidget(CustomDateSpinnerWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue || widget.items != oldWidget.items) {
      int newIndex = widget.items.indexOf(widget.initialValue);
      if (newIndex == -1) newIndex = 0;
      
      if (newIndex != _currentIndex) {
         _currentIndex = newIndex;
        if (_controller.hasClients && _controller.selectedItem != _currentIndex) {
          // Jump if the list or initial value fundamentally changed
           WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_controller.hasClients) {
              _controller.jumpToItem(_currentIndex);
            }
          });
        }
      }
    }
  }


  @override
  void dispose() {
    // Dispose only if created internally
    if (widget.scrollController == null) {
      _controller.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink(); // Handle empty list
    }
    // Ensure currentIndex is valid
    if (_currentIndex >= widget.items.length) {
        _currentIndex = widget.items.length -1;
        if (_controller.hasClients && _controller.selectedItem != _currentIndex) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_controller.hasClients) _controller.jumpToItem(_currentIndex);
             });
        }
    }


    return SizedBox(
      width: 70,
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollEndNotification) {}
          return true;
        },
        child: ListWheelScrollView.useDelegate(
          controller: _controller,
          itemExtent: widget.itemExtent,
          physics: const FixedExtentScrollPhysics(parent: BouncingScrollPhysics()),
          diameterRatio: 0.7,
          useMagnifier: true,
          magnification: 1.1,
          onSelectedItemChanged: (index) {
            if (index >= 0 && index < widget.items.length) {
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 150), () {
                if (mounted && index < widget.items.length) {
                  setState(() {
                    _currentIndex = index;
                  });
                  widget.onSelectedItemChanged(widget.items[index]);
                }
              });
            }
          },
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, index) {
              if (index < 0 || index >= widget.items.length) return null;
              final item = widget.items[index];
              final bool isSelected = (index == _currentIndex);

              return Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    border: isSelected
                        ? Border.all(color: const Color(0xFF2C5545), width: 1.5)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    color: isSelected ? const Color(0xFF2C5545).withOpacity(0.05) : Colors.transparent,
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 18,
                      color: isSelected ? Colors.black : Colors.grey[600],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
            childCount: widget.items.length,
          ),
        ),
      ),
    );
  }
}
