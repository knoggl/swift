// RUN: %empty-directory(%t)

// RUN: %target-swift-frontend -emit-module %S/Inputs/lookup_moduleD.swift -module-name D -o %t -I %t
// RUN: %target-swift-frontend -emit-module %S/Inputs/lookup_moduleC.swift -module-name C -o %t -I %t
// RUN: %target-swift-frontend -emit-module %S/Inputs/lookup_moduleB.swift -module-name B -o %t -I %t
// RUN: %target-swift-frontend -emit-module %S/Inputs/lookup_moduleA.swift -module-name A -o %t -I %t
// RUN: %target-swift-frontend -emit-module %S/Inputs/lookup_module_exportsAC.swift -module-name ExportsAC -o %t -I %t

// FIXME: Remove -verify-ignore-unknown.
// RUN: %target-swift-frontend -typecheck -verify -verify-ignore-unknown -primary-file %s %S/Inputs/lookup_other.swift %S/Inputs/lookup_other2.swift %S/Inputs/lookup_other_compat.swift -I %t

import ExportsAC
import B

infix operator ^^^ : DeclaredAcrossFiles
func ^^^ (lhs: Int, rhs: Int) -> Int { 0 }
func &&& (lhs: Int, rhs: Int) -> Int { 0 }

// FIXME(SR-12132): The operator decl >>> is declared in module A, which we
// should be able to see through ExportsAC.
prefix func >>> (rhs: Double) {} // expected-error {{operator implementation without matching operator declaration}}

// FIXME(SR-12132): We should also see precedencegroups in module A through
// ExportsAC.
infix operator ^^^^ : DeclaredInModuleA // expected-error {{unknown precedence group 'DeclaredInModuleA'}}

// The operator decl for ??? is declared in both modules A and B, but has the
// same default precedence group in both, so there's no ambiguity.
func ??? (lhs: Int, rhs: Int) {}

// Same for ???!, declared in modules ExportsAC and B, but has the same
// precedence group in both.
func ???! (lhs: Int, rhs: Int) {}

// The operator decl for ???? is declared in both modules A and B, and has a
// different precedence group in each. This should therefore be ambiguous.
// However, for compatibility, we don't look through exports in other modules,
// so we don't see the one in module A.
func ???? (lhs: Int, rhs: Int) {}

// The operator decl for ????! is declared in both modules ExportsAC and B, and
// has a different precedence group in each. Therefore ambiguous.
// FIXME: We shouldn't emit the unknown operator decl error.
func ????! (lhs: Int, rhs: Int) {} // expected-error {{ambiguous operator declarations found for operator}}
// expected-error@-1 {{operator implementation without matching operator declaration}}

// Same as ????, the precedencegroup is declared in both modules A and B, but
// we don't look into module A for compatibility.
infix operator <?> : DeclaredInModulesAB

// The precedencegroup is declared in both modules ExportsAC and B, therefore
// ambiguous.
// FIXME: We shouldn't emit the 'unknown precedence group' error.
infix operator <!> : DeclaredInModulesBExportsAC // expected-error {{multiple precedence groups found}}
// expected-error@-1 {{unknown precedence group 'DeclaredInModulesBExportsAC'}}

// This precedencegroup is declared in this module as well as in both modules A
// and B. The decl in this module should shadow the imported ones, but for
// compatibility we don't see module A's decl and take module B's decl.
infix operator <??> : DeclaredInModulesABShadowed

// The operator decl for <? is declared in both modules A and B, but there's no
// meaningful difference between the declarations, so legal.
postfix func <? (lhs: Int) {}

// Same thing, <! is declared in both modules ExportsAC and B, but there's no
// meaningful difference between the declarations, so legal.
postfix func <! (lhs: Int) {}

// This precedencegroup is declared in both modules A and ExportsAC, but the
// latter shadows the former.
infix operator <???> : ShadowsModuleA

// This precedencegroup is declared in modules A, C, and ExportsAC, but the
// latter shadows both of the former.
infix operator <????> : ShadowsModulesAC

// This operator decl is declared in modules A, C, and ExportsAC, but the
// latter shadows both of the former.
func ????? (lhs: Int, rhs: Int) {}

// This operator decl is declared in modules A, C, and ExportsAC, but the
// latter shadows both of the former, despite them having different
// precedencegroups.
func ?????? (lhs: Int, rhs: Int) {}

// FIXME: Module D is imported through exports in both lookup_other and
// lookup_other2, but we fail to detect the fact that we're visiting the same
// thing twice.
infix operator <> : DeclaredInModuleD // expected-error {{unknown precedence group 'DeclaredInModuleD'}}

// Also declared in lookup_other. To preserve compatibility, we allow an
// unambiguous lookup that will favor this declaration over lookup_other.
precedencegroup RedeclaredInModule {} 
infix operator *** : RedeclaredInModule // Okay.

func testOperatorLookup() {
  // In lookup_other, DeclaredAcrossFiles is left associative, whereas in
  // module B it is non-associative. Make sure we use module B's for
  // compatibility.
  _ = 5 ^^^ 5 ^^^ 5
  // expected-error@-1 {{adjacent operators are in unordered precedence groups 'AssignmentPrecedence' and 'DeclaredAcrossFiles'}}
  // expected-error@-2 {{adjacent operators are in non-associative precedence group 'DeclaredAcrossFiles'}}
  // expected-error@-3 {{cannot convert value of type '()' to expected argument type 'Int'}}

  // Same for &&&, in lookup_other it is declared as left associative.
  _ = 5 &&& 5 &&& 5 // expected-error {{adjacent operators are in non-associative precedence group 'DefaultPrecedence'}}

  // The operator >>> is declared in module A, which we should be able to see
  // through ExportsAC.
  >>>1

  // We've been evil and overriden TernaryPrecedence in both modules A and B.
  // FIXME: We shouldn't emit the 'broken stdlib' error.
  true ? () : () // expected-error {{multiple precedence groups found}}
  // expected-error@-1 {{broken standard library: missing builtin precedence group 'TernaryPrecedence'}}
}

precedencegroup CastingPrecedence {
  lowerThan: AssignmentPrecedence
}

func testBuiltinPrecedenceGroupOverriding() {
  // Evil, but allowed.
  var x = 0
  x = 0 as Int // expected-error {{cannot convert value of type '()' to type 'Int' in coercion}}
}
