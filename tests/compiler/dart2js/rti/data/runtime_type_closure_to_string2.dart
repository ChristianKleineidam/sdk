// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart = 2.7

/*spec:nnbd-off|prod:nnbd-off.class: Class:*/
class Class<T> {
  /*spec:nnbd-off|prod:nnbd-off.member: Class.:*/
  Class();
}

/*spec:nnbd-off|prod:nnbd-off.member: main:*/
main() {
  /*spec:nnbd-off|spec:nnbd-sdk.needsArgs,needsSignature*/
  local1<T>() {}

  /*spec:nnbd-off|spec:nnbd-sdk.needsArgs,needsSignature,selectors=[Selector(call, call, arity=2, types=1)]*/
  local2<T>(t, s) => t;

  print('${local1.runtimeType}');
  local2(0, '');
  new Class();
}
