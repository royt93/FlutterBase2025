import 'dart:async';

class BoolEvent {
  final bool value;

  BoolEvent(this.value);
}

class SimpleEventBus {
  static final SimpleEventBus _instance = SimpleEventBus._internal();

  factory SimpleEventBus() => _instance;

  final StreamController<BoolEvent> _controller = StreamController.broadcast();

  SimpleEventBus._internal();

  Stream<BoolEvent> get onBoolEvent => _controller.stream;

  void fire(BoolEvent event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}
