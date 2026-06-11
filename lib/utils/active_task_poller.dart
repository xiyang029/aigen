import 'dart:async';

import 'package:flutter/widgets.dart';

class ActiveTaskPoller with WidgetsBindingObserver {
  ActiveTaskPoller({this.interval = const Duration(seconds: 5)});

  // 轮询间隔，用于控制活跃任务状态刷新频率。
  final Duration interval;

  // 周期轮询定时器，页面存在活跃任务时启动。
  Timer? _timer;

  // 当前页面注入的轮询回调，用于拉取最新任务状态。
  Future<void> Function()? _onTick;

  // 标记当前是否已有轮询请求在执行，避免并发重复请求。
  bool _ticking = false;

  // 标记是否已经注册应用生命周期监听，避免重复注册。
  bool _observingLifecycle = false;

  // 根据当前任务活跃状态启动或停止轮询。
  void sync({
    required bool shouldPoll,
    required Future<void> Function() onTick,
  }) {
    _onTick = onTick;
    if (shouldPoll) {
      _startObservingLifecycle();
      _timer ??= Timer.periodic(interval, (_) => _tick());
      return;
    }
    stop();
  }

  // 停止轮询并解除生命周期监听。
  void stop() {
    _timer?.cancel();
    _timer = null;
    _ticking = false;
    _stopObservingLifecycle();
  }

  // 释放轮询器占用的定时器和生命周期监听。
  void dispose() => stop();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _timer != null) {
      unawaited(_tick());
    }
  }

  // 注册应用生命周期监听，用于回到前台时立即刷新任务状态。
  void _startObservingLifecycle() {
    if (_observingLifecycle) return;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
  }

  // 解除应用生命周期监听，避免轮询停止后继续收到回调。
  void _stopObservingLifecycle() {
    if (!_observingLifecycle) return;
    WidgetsBinding.instance.removeObserver(this);
    _observingLifecycle = false;
  }

  // 执行一次轮询回调，并保护并发状态。
  Future<void> _tick() async {
    final onTick = _onTick;
    if (_ticking || onTick == null) return;
    _ticking = true;
    try {
      await onTick();
    } finally {
      _ticking = false;
    }
  }
}

