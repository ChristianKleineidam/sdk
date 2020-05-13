// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart = 2.7

// Test derived from language_2/generic_methods_dynamic_test/05

/*prod:nnbd-off.class: global#JSArray:deps=[List],explicit=[JSArray],needsArgs*/
/*spec:nnbd-off.class: global#JSArray:deps=[ArrayIterator,List],direct,explicit=[JSArray,JSArray.E,JSArray<ArrayIterator.E>],implicit=[JSArray.E],needsArgs*/
/*spec:nnbd-off.class: global#List:deps=[C.bar],explicit=[List,List<B>,List<String>],indirect,needsArgs*/

/*prod:nnbd-off.class: global#List:deps=[C.bar],explicit=[List,List<B>],needsArgs*/
import "package:expect/expect.dart";

class A {}

/*spec:nnbd-off.class: B:explicit=[List<B>],implicit=[B]*/
/*prod:nnbd-off.class: B:explicit=[List<B>]*/
/*spec:nnbd-sdk.class: B:explicit=[List<B*>*],implicit=[B]*/
/*prod:nnbd-sdk.class: B:explicit=[List<B*>*]*/
class B {}

class C {
  /*spec:nnbd-sdk.member: C.bar:direct,explicit=[Iterable<bar.T*>*],implicit=[bar.T],needsArgs,selectors=[Selector(call, bar, arity=1, types=1)]*/
  /*spec:nnbd-off.member: C.bar:direct,explicit=[Iterable<bar.T>],implicit=[bar.T],needsArgs,selectors=[Selector(call, bar, arity=1, types=1)]*/
  /*prod:nnbd-off|prod:nnbd-sdk.member: C.bar:needsArgs,selectors=[Selector(call, bar, arity=1, types=1)]*/
  List<T> bar<T>(Iterable<T> t) => <T>[t.first];
}

main() {
  C c = new C();
  dynamic x = c.bar<B>(<B>[new B()]);
  Expect.isTrue(x is List<B>);
}
