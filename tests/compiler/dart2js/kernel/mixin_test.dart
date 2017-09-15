// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Test that the optimized algorithm for mixin applications matches the mixins
// generated by fasta.
library dart2js.kernel.mixins_test;

import 'package:async_helper/async_helper.dart';
import 'package:compiler/src/commandline_options.dart';
import 'package:compiler/src/common_elements.dart';
import 'package:compiler/src/compiler.dart';
import 'package:compiler/src/elements/entities.dart';
import 'package:compiler/src/elements/types.dart';
import 'package:compiler/src/kernel/kernel_strategy.dart';
import 'package:compiler/src/resolution/class_hierarchy.dart';
import 'package:compiler/src/universe/class_set.dart';
import 'package:compiler/src/world.dart';
import 'package:expect/expect.dart';
import '../memory_compiler.dart';
import '../equivalence/check_helpers.dart';
import 'test_helpers.dart';
import 'compiler_helper.dart';

const SOURCE = const {
  'main.dart': '''

class Super {}
class Mixin1 {}
class Mixin2 {}
class Sub1 extends Super with Mixin1 {}
class Sub2 extends Super with Mixin1, Mixin2 {}
class NamedSub1 = Super with Mixin1;
class NamedSub2 = Super with Mixin1, Mixin2;


class GenericSuper<T> {}
class GenericMixin1<T> {}
class GenericMixin2<T> {}
class GenericSub1<T> extends GenericSuper<T> with GenericMixin1<T> {}
class GenericSub2<T> extends GenericSuper<T>
    with GenericMixin1<T>, GenericMixin2<T> {}
class GenericNamedSub1<T> = GenericSuper<T> with GenericMixin1<T>;
class GenericNamedSub2<T> = GenericSuper<T>
    with GenericMixin1<T>, GenericMixin2<T>;

class FixedSub1a extends GenericSuper<int> with GenericMixin1<int> {}
class FixedSub1b extends GenericSuper<int> with GenericMixin1<double> {}
class FixedSub2a extends GenericSuper<int>
    with GenericMixin1<int>, GenericMixin2<int> {}
class FixedSub2b extends GenericSuper<double>
    with GenericMixin1<double>, GenericMixin2<double> {}

class GenericMultiMixin<T, S> {}
class GenericSub<T, S> = Object with GenericMultiMixin<T, S>;
class FixedSub = Object with GenericMultiMixin<int, String>;


main() {
  new Super();
  new Mixin1();
  new Mixin2();
  new Sub1();
  new Sub2();
  new NamedSub1();
  new NamedSub2();

  new GenericSuper<int>();
  new GenericMixin1<int>();
  new GenericMixin2<int>();
  new GenericSub1<int>();
  new GenericSub2<int>();
  new GenericNamedSub1<int>();
  new GenericNamedSub2<int>();

  new FixedSub1a();
  new FixedSub1b();
  new FixedSub2a();
  new FixedSub2b();

  new GenericSub<int, String>();
  new FixedSub();
}
'''
};

Map<ClassEntity, String> generateClassEnv(
    ElementEnvironment env, DartTypes types) {
  Map<ClassEntity, String> classEnv = <ClassEntity, String>{};

  void createEnv(ClassEntity cls) {
    classEnv.putIfAbsent(cls, () {
      InterfaceType thisType = env.getThisType(cls);
      StringBuffer sb = new StringBuffer();
      sb.write('class ');
      sb.write(env.getThisType(cls));
      ClassEntity superclass = env.getSuperClass(cls);
      if (superclass != null) {
        createEnv(superclass);
        sb.write(' extends ');
        sb.write(types.asInstanceOf(thisType, superclass));
      }
      return sb.toString();
    });
  }

  env.forEachClass(env.mainLibrary, createEnv);

  return classEnv;
}

main(List<String> args) {
  asyncTest(() async {
    useOptimizedMixins = true;

    Uri entryPoint = await createTemp(Uri.parse('memory:main.dart'), SOURCE,
        printSteps: true);

    print(
        '---- compiler from ast -----------------------------------------------');
    var result =
        await runCompiler(entryPoint: entryPoint, options: [Flags.analyzeOnly]);
    Compiler compiler1 = result.compiler;

    Compiler compiler2 = await compileWithDill(
        entryPoint: entryPoint,
        memorySourceFiles: {},
        options: [Flags.analyzeOnly],
        printSteps: true);

    ElementEnvironment env1 = compiler1.frontendStrategy.elementEnvironment;
    DartTypes types1 = compiler1.frontendStrategy.dartTypes;
    ClosedWorld closedWorld1 = compiler1.resolutionWorldBuilder.closeWorld();

    KernelFrontEndStrategy frontendStrategy = compiler2.frontendStrategy;
    ElementEnvironment env2 = frontendStrategy.elementEnvironment;
    DartTypes types2 = frontendStrategy.dartTypes;
    ClosedWorld closedWorld2 = compiler2.resolutionWorldBuilder.closeWorld();

    KernelEquivalence equivalence =
        new KernelEquivalence(frontendStrategy.elementMap);

    if (args.contains('-v')) {
      Map<ClassEntity, String> classEnv1 = generateClassEnv(env1, types1);
      Map<ClassEntity, String> classEnv2 = generateClassEnv(env2, types2);

      print('----');
      classEnv1.forEach((ClassEntity cls, String env) {
        print(env);
      });
      print('----');
      classEnv2.forEach((ClassEntity cls, String env) {
        print(env);
      });
    }

    void checkClasses(ClassEntity cls1, ClassEntity cls2) {
      if (cls1 == cls2) return;
      Expect.isNotNull(cls1, 'Missing class ${cls2.name}');
      Expect.isNotNull(cls2, 'Missing class ${cls1.name}');

      check(cls1.library, cls2.library, 'class ${cls1.name}', cls1, cls2,
          equivalence.entityEquivalence);
      InterfaceType thisType1 = types1.getThisType(cls1);
      InterfaceType thisType2 = types2.getThisType(cls2);
      check(cls1, cls2, 'thisType', thisType1, thisType2,
          equivalence.typeEquivalence);
      check(cls1, cls2, 'supertype', types1.getSupertype(cls1),
          types2.getSupertype(cls2), equivalence.typeEquivalence);
      checkClasses(env1.getSuperClass(cls1), env2.getSuperClass(cls2));

      List<DartType> mixins1 = <DartType>[];
      env1.forEachMixin(cls1, (ClassEntity mixin) {
        mixins1.add(types1.asInstanceOf(thisType1, mixin));
      });
      List<DartType> mixins2 = <DartType>[];
      env2.forEachMixin(cls2, (ClassEntity mixin) {
        mixins2.add(types2.asInstanceOf(thisType2, mixin));
      });
      checkLists(
          mixins1, mixins2, '${cls1.name} mixins', equivalence.typeEquivalence);

      checkLists(
          types1.getInterfaces(cls1).toList(),
          types2.getInterfaces(cls2).toList(),
          '${cls1.name} interfaces',
          equivalence.typeEquivalence);
      checkLists(
          types1.getSupertypes(cls1).toList(),
          types2.getSupertypes(cls2).toList(),
          '${cls1.name} supertypes',
          equivalence.typeEquivalence);

      if (cls1 == compiler1.frontendStrategy.commonElements.objectClass) return;

      ClassHierarchyNode node1 = closedWorld1.getClassHierarchyNode(cls1);
      ClassHierarchyNode node2 = closedWorld2.getClassHierarchyNode(cls2);
      checkSets(
          new Set.from(node1.directSubclasses),
          new Set.from(node2.directSubclasses),
          '${cls1.name} direct subclasses',
          (a, b) => equivalence.entityEquivalence(a.cls, b.cls));
    }

    env1.forEachClass(env1.mainLibrary, (ClassEntity cls1) {
      ClassEntity cls2 = env2.lookupClass(env2.mainLibrary, cls1.name);
      checkClasses(cls1, cls2);
    });
  });
}
