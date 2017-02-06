// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:front_end/src/base/errors.dart';
import 'package:front_end/src/base/jenkins_smi_hash.dart';
import 'package:front_end/src/fasta/scanner/error_token.dart' as fasta;
import 'package:front_end/src/fasta/scanner/keyword.dart' as fasta;
import 'package:front_end/src/fasta/scanner/string_scanner.dart' as fasta;
import 'package:front_end/src/fasta/scanner/token.dart' as fasta;
import 'package:front_end/src/fasta/scanner/token_constants.dart' as fasta;
import 'package:front_end/src/scanner/errors.dart';
import 'package:front_end/src/scanner/reader.dart';
import 'package:front_end/src/scanner/scanner.dart';
import 'package:front_end/src/scanner/token.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(CharSequenceReaderTest);
    defineReflectiveTests(KeywordStateTest);
    defineReflectiveTests(ScannerTest);
    defineReflectiveTests(ScannerTest_Fasta);
    defineReflectiveTests(TokenTypeTest);
  });
}

@reflectiveTest
class CharSequenceReaderTest {
  void test_advance() {
    CharSequenceReader reader = new CharSequenceReader("x");
    expect(reader.advance(), 0x78);
    expect(reader.advance(), -1);
    expect(reader.advance(), -1);
  }

  void test_creation() {
    expect(new CharSequenceReader("x"), isNotNull);
  }

  void test_getOffset() {
    CharSequenceReader reader = new CharSequenceReader("x");
    expect(reader.offset, -1);
    reader.advance();
    expect(reader.offset, 0);
    reader.advance();
    expect(reader.offset, 0);
  }

  void test_getString() {
    CharSequenceReader reader = new CharSequenceReader("xyzzy");
    reader.offset = 3;
    expect(reader.getString(1, 0), "yzz");
    expect(reader.getString(2, 1), "zzy");
  }

  void test_peek() {
    CharSequenceReader reader = new CharSequenceReader("xy");
    expect(reader.peek(), 0x78);
    expect(reader.peek(), 0x78);
    reader.advance();
    expect(reader.peek(), 0x79);
    expect(reader.peek(), 0x79);
    reader.advance();
    expect(reader.peek(), -1);
    expect(reader.peek(), -1);
  }

  void test_setOffset() {
    CharSequenceReader reader = new CharSequenceReader("xyz");
    reader.offset = 2;
    expect(reader.offset, 2);
  }
}

@reflectiveTest
class KeywordStateTest {
  void test_KeywordState() {
    //
    // Generate the test data to be scanned.
    //
    List<Keyword> keywords = Keyword.values;
    int keywordCount = keywords.length;
    List<String> textToTest = new List<String>(keywordCount * 3);
    for (int i = 0; i < keywordCount; i++) {
      String syntax = keywords[i].syntax;
      textToTest[i] = syntax;
      textToTest[i + keywordCount] = "${syntax}x";
      textToTest[i + keywordCount * 2] = syntax.substring(0, syntax.length - 1);
    }
    //
    // Scan each of the identifiers.
    //
    KeywordState firstState = KeywordState.KEYWORD_STATE;
    for (int i = 0; i < textToTest.length; i++) {
      String text = textToTest[i];
      int index = 0;
      int length = text.length;
      KeywordState state = firstState;
      while (index < length && state != null) {
        state = state.next(text.codeUnitAt(index));
        index++;
      }
      if (i < keywordCount) {
        // keyword
        expect(state, isNotNull);
        expect(state.keyword(), isNotNull);
        expect(state.keyword(), keywords[i]);
      } else if (i < keywordCount * 2) {
        // keyword + "x"
        expect(state, isNull);
      } else {
        // keyword.substring(0, keyword.length() - 1)
        expect(state, isNotNull);
      }
    }
  }
}

@reflectiveTest
class ScannerTest extends ScannerTestBase {
  @override
  Token _scanWithListener(String source, _ErrorListener listener,
      {bool genericMethodComments: false,
      bool lazyAssignmentOperators: false}) {
    Scanner scanner =
        new _TestScanner(new CharSequenceReader(source), listener);
    scanner.scanGenericMethodComments = genericMethodComments;
    scanner.scanLazyAssignmentOperators = lazyAssignmentOperators;
    return scanner.tokenize();
  }
}

@reflectiveTest
class ScannerTest_Fasta extends ScannerTestBase {
  final _keywordMap = {
    "assert": Keyword.ASSERT,
    "break": Keyword.BREAK,
    "case": Keyword.CASE,
    "catch": Keyword.CATCH,
    "class": Keyword.CLASS,
    "const": Keyword.CONST,
    "continue": Keyword.CONTINUE,
    "default": Keyword.DEFAULT,
    "do": Keyword.DO,
    "else": Keyword.ELSE,
    "enum": Keyword.ENUM,
    "extends": Keyword.EXTENDS,
    "false": Keyword.FALSE,
    "final": Keyword.FINAL,
    "finally": Keyword.FINALLY,
    "for": Keyword.FOR,
    "if": Keyword.IF,
    "in": Keyword.IN,
    "new": Keyword.NEW,
    "null": Keyword.NULL,
    "rethrow": Keyword.RETHROW,
    "return": Keyword.RETURN,
    "super": Keyword.SUPER,
    "switch": Keyword.SWITCH,
    "this": Keyword.THIS,
    "throw": Keyword.THROW,
    "true": Keyword.TRUE,
    "try": Keyword.TRY,
    "var": Keyword.VAR,
    "void": Keyword.VOID,
    "while": Keyword.WHILE,
    "with": Keyword.WITH,
    "is": Keyword.IS,
    "abstract": Keyword.ABSTRACT,
    "as": Keyword.AS,
    "covariant": Keyword.COVARIANT,
    "dynamic": Keyword.DYNAMIC,
    "export": Keyword.EXPORT,
    "external": Keyword.EXTERNAL,
    "factory": Keyword.FACTORY,
    "get": Keyword.GET,
    "implements": Keyword.IMPLEMENTS,
    "import": Keyword.IMPORT,
    "library": Keyword.LIBRARY,
    "operator": Keyword.OPERATOR,
    "part": Keyword.PART,
    "set": Keyword.SET,
    "static": Keyword.STATIC,
    "typedef": Keyword.TYPEDEF,
    "deferred": Keyword.DEFERRED,
  };

  @override
  @failingTest
  void test_ampersand_ampersand_eq() {
    // TODO(paulberry,ahe): Fasta doesn't support `&&=` yet
    super.test_ampersand_ampersand_eq();
  }

  @override
  @failingTest
  void test_bar_bar_eq() {
    // TODO(paulberry,ahe): Fasta doesn't support `||=` yet
    super.test_bar_bar_eq();
  }

  @override
  @failingTest
  void test_comment_generic_method_type_assign() {
    // TODO(paulberry,ahe): Fasta doesn't support generic method comment syntax.
    super.test_comment_generic_method_type_assign();
  }

  @override
  @failingTest
  void test_comment_generic_method_type_list() {
    // TODO(paulberry,ahe): Fasta doesn't support generic method comment syntax.
    super.test_comment_generic_method_type_list();
  }

  @override
  @failingTest
  void test_comment_multi_unterminated() {
    // TODO(paulberry,ahe): see UnimplementedError("distinguish unterminated
    // errors")
    super.test_comment_multi_unterminated();
  }

  @override
  @failingTest
  void test_comment_single() {
    // TODO(paulberry,ahe): See TODO comment below in _translateTokenInfoKind().
    super.test_comment_single();
  }

  @override
  @failingTest
  void test_double_missingDigitInExponent() {
    // TODO(paulberry,ahe): see UnimplementedError("distinguish unterminated
    // errors")
    super.test_double_missingDigitInExponent();
  }

  @override
  @failingTest
  void test_hexidecimal_missingDigit() {
    // TODO(paulberry,ahe): see UnimplementedError("distinguish unterminated
    // errors")
    super.test_hexidecimal_missingDigit();
  }

  @override
  @failingTest
  void test_index() {
    // TODO(paulberry,ahe): "[]" should be parsed as a single token.
    super.test_index();
  }

  @override
  @failingTest
  void test_index_eq() {
    // TODO(paulberry,ahe): "[]=" should be parsed as a single token.
    super.test_index_eq();
  }

  @override
  @failingTest
  void test_scriptTag_withArgs() {
    // TODO(paulberry,ahe): script tags are needed by analyzer.
    super.test_scriptTag_withArgs();
  }

  @override
  @failingTest
  void test_scriptTag_withoutSpace() {
    // TODO(paulberry,ahe): script tags are needed by analyzer.
    super.test_scriptTag_withoutSpace();
  }

  @override
  @failingTest
  void test_scriptTag_withSpace() {
    // TODO(paulberry,ahe): script tags are needed by analyzer.
    super.test_scriptTag_withSpace();
  }

  @override
  @failingTest
  void test_string_multi_unterminated() {
    // TODO(paulberry,ahe): bad error recovery.
    super.test_string_multi_unterminated();
  }

  @override
  @failingTest
  void test_string_multi_unterminated_interpolation_block() {
    // TODO(paulberry,ahe): bad error recovery.
    super.test_string_multi_unterminated_interpolation_block();
  }

  @override
  @failingTest
  void test_string_multi_unterminated_interpolation_identifier() {
    // TODO(paulberry,ahe): bad error recovery.
    super.test_string_multi_unterminated_interpolation_identifier();
  }

  @override
  @failingTest
  void test_string_raw_multi_unterminated() {
    // TODO(paulberry,ahe): bad error recovery.
    super.test_string_raw_multi_unterminated();
  }

  @override
  @failingTest
  void test_string_raw_simple_unterminated_eof() {
    // TODO(paulberry,ahe): bad error recovery.
    super.test_string_raw_simple_unterminated_eof();
  }

  @override
  @failingTest
  void test_string_raw_simple_unterminated_eol() {
    // TODO(paulberry,ahe): bad error recovery.
    super.test_string_raw_simple_unterminated_eol();
  }

  @override
  @failingTest
  void test_string_simple_interpolation_missingIdentifier() {
    // TODO(paulberry,ahe): bad error recovery.
    super.test_string_simple_interpolation_missingIdentifier();
  }

  @override
  @failingTest
  void test_string_simple_interpolation_nonIdentifier() {
    // TODO(paulberry,ahe): bad error recovery.
    super.test_string_simple_interpolation_nonIdentifier();
  }

  @override
  @failingTest
  void test_string_simple_unterminated_eof() {
    // TODO(paulberry,ahe): bad error recovery.
    super.test_string_simple_unterminated_eof();
  }

  @override
  @failingTest
  void test_string_simple_unterminated_eol() {
    // TODO(paulberry,ahe): bad error recovery.
    super.test_string_simple_unterminated_eol();
  }

  @override
  @failingTest
  void test_string_simple_unterminated_interpolation_block() {
    // TODO(paulberry,ahe): bad error recovery.
    super.test_string_simple_unterminated_interpolation_block();
  }

  @override
  @failingTest
  void test_string_simple_unterminated_interpolation_identifier() {
    // TODO(paulberry,ahe): bad error recovery.
    super.test_string_simple_unterminated_interpolation_identifier();
  }

  @override
  Token _scanWithListener(String source, _ErrorListener listener,
      {bool genericMethodComments: false,
      bool lazyAssignmentOperators: false}) {
    if (genericMethodComments) {
      // Fasta doesn't support generic method comments.
      // TODO(paulberry): once the analyzer toolchain no longer needs generic
      // method comments, remove tests that exercise them.
      fail('No generic method comment support in Fasta');
    }
    // Note: Fasta always supports lazy assignment operators (`&&=` and `||=`),
    // so we can ignore the `lazyAssignmentOperators` flag.
    // TODO(paulberry): once lazyAssignmentOperators are fully supported by
    // Dart, remove this flag.
    var scanner = new fasta.StringScanner(source, includeComments: true);
    var token = scanner.tokenize();
    var analyzerTokenHead = new Token(null, 0);
    analyzerTokenHead.previous = analyzerTokenHead;
    var analyzerTokenTail = analyzerTokenHead;
    // TODO(paulberry,ahe): Fasta includes comments directly in the token
    // stream, rather than pointing to them via a "precedingComment" pointer, as
    // analyzer does.  This seems like it will complicate parsing and other
    // operations.
    CommentToken currentCommentHead;
    CommentToken currentCommentTail;
    while (true) {
      if (token is fasta.ErrorToken) {
        var error = _translateErrorToken(token, source.length);
        if (error != null) {
          listener.errors.add(error);
        }
      } else if (token is fasta.StringToken &&
          token.info.kind == fasta.COMMENT_TOKEN) {
        var translatedToken = _translateToken(token, null) as CommentToken;
        if (currentCommentHead == null) {
          currentCommentHead = currentCommentTail = translatedToken;
        } else {
          currentCommentTail.setNext(translatedToken);
          currentCommentTail = translatedToken;
        }
      } else {
        var translatedToken = _translateToken(token, currentCommentHead);
        translatedToken.setNext(translatedToken);
        currentCommentHead = currentCommentTail = null;
        analyzerTokenTail.setNext(translatedToken);
        translatedToken.previous = analyzerTokenTail;
        analyzerTokenTail = translatedToken;
      }
      if (token.isEof) {
        return analyzerTokenHead.next;
      }
      token = token.next;
    }
  }

  _TestError _translateErrorToken(fasta.ErrorToken token, int inputLength) {
    int charOffset = token.charOffset;
    // TODO(paulberry,ahe): why is endOffset sometimes null?
    int endOffset = token.endOffset ?? charOffset;
    _TestError _makeError(ScannerErrorCode errorCode, List<Object> arguments) {
      int errorLength = endOffset - charOffset;
      if (charOffset == inputLength) {
        // Analyzer never generates an error message past the end of the input,
        // since such an error would not be visible in an editor.
        // TODO(paulberry,ahe): would it make sense to replicate this behavior
        // in fasta, or move it elsewhere in analyzer?
        charOffset--;
      }
      if (errorLength == 0) {
        // Analyzer never generates an error message of length zero,
        // since such an error would not be visible in an editor.
        // TODO(paulberry,ahe): would it make sense to replicate this behavior
        // in fasta, or move it elsewhere in analyzer?
        errorLength = 1;
      }
      return new _TestError(charOffset, errorLength, errorCode, arguments);
    }

    if (token is fasta.UnterminatedToken) {
      // TODO(paulberry,ahe): How to tell what kind of error to
      // report?  It could be ScannerErrorCode.UNTERMINATED_STRING_LITERAL,
      // ScannerErrorCode.MISSING_HEX_DIGIT, or
      // ScannerErrorCode.UNTERMINATED_MULTI_LINE_COMMENT
      return _makeError(
          throw new UnimplementedError("distinguish unterminated errors"),
          null);
    } else if (token is fasta.UnmatchedToken) {
      return null;
    } else if (token is fasta.NonAsciiIdentifierToken) {
      return _makeError(ScannerErrorCode.ILLEGAL_CHARACTER, [token.character]);
    } else if (token is fasta.NonAsciiWhitespaceToken) {
      return _makeError(ScannerErrorCode.ILLEGAL_CHARACTER, [token.character]);
    }
    throw new UnimplementedError('${token.runtimeType}');
  }

  Keyword _translateKeyword(String syntax) =>
      _keywordMap[syntax] ?? (throw new UnimplementedError('$syntax'));

  Token _translateToken(fasta.Token token, CommentToken comment) {
    var type = _translateTokenInfoKind(token.info.kind);
    int offset = token.charOffset;
    Token makeStringToken(String value) {
      if (comment == null) {
        return new StringToken(type, value, offset);
      } else {
        return new StringTokenWithComment(type, value, offset, comment);
      }
    }

    Token makeKeywordToken(Keyword keyword) {
      if (comment == null) {
        return new KeywordToken(keyword, offset);
      } else {
        return new KeywordTokenWithComment(keyword, offset, comment);
      }
    }

    Token makeBeginToken() {
      if (comment == null) {
        return new BeginToken(type, offset);
      } else {
        return new BeginTokenWithComment(type, offset, comment);
      }
    }

    Token makeCommentToken() {
      return new CommentToken(type, token.value, offset);
    }

    if (token is fasta.StringToken) {
      if (token.info.kind == fasta.COMMENT_TOKEN) {
        return makeCommentToken();
      } else {
        return makeStringToken(token.value);
      }
    } else if (token is fasta.KeywordToken) {
      return makeKeywordToken(_translateKeyword(token.keyword.syntax));
    } else if (token is fasta.SymbolToken) {
      if (token is fasta.BeginGroupToken) {
        if (type == TokenType.LT) {
          return makeStringToken(token.value);
        } else {
          return makeBeginToken();
        }
      } else {
        return makeStringToken(token.value);
      }
    }
    throw new UnimplementedError('${token.runtimeType}');
  }

  TokenType _translateTokenInfoKind(int kind) {
    switch (kind) {
      case fasta.EOF_TOKEN:
        return TokenType.EOF;
      case fasta.KEYWORD_TOKEN:
        return TokenType.KEYWORD;
      case fasta.IDENTIFIER_TOKEN:
        return TokenType.IDENTIFIER;
      case fasta.BAD_INPUT_TOKEN:
        return TokenType.STRING;
      case fasta.DOUBLE_TOKEN:
        return TokenType.DOUBLE;
      case fasta.INT_TOKEN:
        return TokenType.INT;
      case fasta.HEXADECIMAL_TOKEN:
        return TokenType.HEXADECIMAL;
      case fasta.STRING_TOKEN:
        return TokenType.STRING;
      case fasta.AMPERSAND_TOKEN:
        return TokenType.AMPERSAND;
      case fasta.BACKPING_TOKEN:
        return TokenType.BACKPING;
      case fasta.BACKSLASH_TOKEN:
        return TokenType.BACKSLASH;
      case fasta.BANG_TOKEN:
        return TokenType.BANG;
      case fasta.BAR_TOKEN:
        return TokenType.BAR;
      case fasta.COLON_TOKEN:
        return TokenType.COLON;
      case fasta.COMMA_TOKEN:
        return TokenType.COMMA;
      case fasta.EQ_TOKEN:
        return TokenType.EQ;
      case fasta.GT_TOKEN:
        return TokenType.GT;
      case fasta.HASH_TOKEN:
        return TokenType.HASH;
      case fasta.OPEN_CURLY_BRACKET_TOKEN:
        return TokenType.OPEN_CURLY_BRACKET;
      case fasta.OPEN_SQUARE_BRACKET_TOKEN:
        return TokenType.OPEN_SQUARE_BRACKET;
      case fasta.OPEN_PAREN_TOKEN:
        return TokenType.OPEN_PAREN;
      case fasta.LT_TOKEN:
        return TokenType.LT;
      case fasta.MINUS_TOKEN:
        return TokenType.MINUS;
      case fasta.PERIOD_TOKEN:
        return TokenType.PERIOD;
      case fasta.PLUS_TOKEN:
        return TokenType.PLUS;
      case fasta.QUESTION_TOKEN:
        return TokenType.QUESTION;
      case fasta.AT_TOKEN:
        return TokenType.AT;
      case fasta.CLOSE_CURLY_BRACKET_TOKEN:
        return TokenType.CLOSE_CURLY_BRACKET;
      case fasta.CLOSE_SQUARE_BRACKET_TOKEN:
        return TokenType.CLOSE_SQUARE_BRACKET;
      case fasta.CLOSE_PAREN_TOKEN:
        return TokenType.CLOSE_PAREN;
      case fasta.SEMICOLON_TOKEN:
        return TokenType.SEMICOLON;
      case fasta.SLASH_TOKEN:
        return TokenType.SLASH;
      case fasta.TILDE_TOKEN:
        return TokenType.TILDE;
      case fasta.STAR_TOKEN:
        return TokenType.STAR;
      case fasta.PERCENT_TOKEN:
        return TokenType.PERCENT;
      case fasta.CARET_TOKEN:
        return TokenType.CARET;
      case fasta.STRING_INTERPOLATION_TOKEN:
        return TokenType.STRING_INTERPOLATION_EXPRESSION;
      case fasta.LT_EQ_TOKEN:
        return TokenType.LT_EQ;
      case fasta.FUNCTION_TOKEN:
        return TokenType.FUNCTION;
      case fasta.SLASH_EQ_TOKEN:
        return TokenType.SLASH_EQ;
      case fasta.PERIOD_PERIOD_PERIOD_TOKEN:
        return TokenType.PERIOD_PERIOD_PERIOD;
      case fasta.PERIOD_PERIOD_TOKEN:
        return TokenType.PERIOD_PERIOD;
      case fasta.EQ_EQ_EQ_TOKEN:
        // TODO(paulberry,ahe): what is this?
        throw new UnimplementedError();
      case fasta.EQ_EQ_TOKEN:
        return TokenType.EQ_EQ;
      case fasta.LT_LT_EQ_TOKEN:
        return TokenType.LT_LT_EQ;
      case fasta.LT_LT_TOKEN:
        return TokenType.LT_LT;
      case fasta.GT_EQ_TOKEN:
        return TokenType.GT_EQ;
      case fasta.GT_GT_EQ_TOKEN:
        return TokenType.GT_GT_EQ;
      case fasta.INDEX_EQ_TOKEN:
        return TokenType.INDEX_EQ;
      case fasta.INDEX_TOKEN:
        return TokenType.INDEX;
      case fasta.BANG_EQ_EQ_TOKEN:
        // TODO(paulberry,ahe): what is this?
        throw new UnimplementedError();
      case fasta.BANG_EQ_TOKEN:
        return TokenType.BANG_EQ;
      case fasta.AMPERSAND_AMPERSAND_TOKEN:
        return TokenType.AMPERSAND_AMPERSAND;
      case fasta.AMPERSAND_EQ_TOKEN:
        return TokenType.AMPERSAND_EQ;
      case fasta.BAR_BAR_TOKEN:
        return TokenType.BAR_BAR;
      case fasta.BAR_EQ_TOKEN:
        return TokenType.BAR_EQ;
      case fasta.STAR_EQ_TOKEN:
        return TokenType.STAR_EQ;
      case fasta.PLUS_PLUS_TOKEN:
        return TokenType.PLUS_PLUS;
      case fasta.PLUS_EQ_TOKEN:
        return TokenType.PLUS_EQ;
      case fasta.MINUS_MINUS_TOKEN:
        return TokenType.MINUS_MINUS;
      case fasta.MINUS_EQ_TOKEN:
        return TokenType.MINUS_EQ;
      case fasta.TILDE_SLASH_EQ_TOKEN:
        return TokenType.TILDE_SLASH_EQ;
      case fasta.TILDE_SLASH_TOKEN:
        return TokenType.TILDE_SLASH;
      case fasta.PERCENT_EQ_TOKEN:
        return TokenType.PERCENT_EQ;
      case fasta.GT_GT_TOKEN:
        return TokenType.GT_GT;
      case fasta.CARET_EQ_TOKEN:
        return TokenType.CARET_EQ;
      case fasta.COMMENT_TOKEN:
        // TODO(paulberry,ahe): how to distinguish multi-line from
        // single-line comments?  Causes a failure in test_comment_single().
        return TokenType.MULTI_LINE_COMMENT;
      case fasta.STRING_INTERPOLATION_IDENTIFIER_TOKEN:
        return TokenType.STRING_INTERPOLATION_IDENTIFIER;
      case fasta.QUESTION_PERIOD_TOKEN:
        return TokenType.QUESTION_PERIOD;
      case fasta.QUESTION_QUESTION_TOKEN:
        return TokenType.QUESTION_QUESTION;
      case fasta.QUESTION_QUESTION_EQ_TOKEN:
        return TokenType.QUESTION_QUESTION_EQ;
      default:
        throw new UnimplementedError('$kind');
    }
  }
}

abstract class ScannerTestBase {
  void fail_incomplete_string_interpolation() {
    // https://code.google.com/p/dart/issues/detail?id=18073
    _assertErrorAndTokens(
        ScannerErrorCode.UNTERMINATED_STRING_LITERAL, 9, "\"foo \${bar", [
      new StringToken(TokenType.STRING, "\"foo ", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_EXPRESSION, "\${", 5),
      new StringToken(TokenType.IDENTIFIER, "bar", 7)
    ]);
  }

  void test_ampersand() {
    _assertToken(TokenType.AMPERSAND, "&");
  }

  void test_ampersand_ampersand() {
    _assertToken(TokenType.AMPERSAND_AMPERSAND, "&&");
  }

  void test_ampersand_ampersand_eq() {
    _assertToken(TokenType.AMPERSAND_AMPERSAND_EQ, "&&=",
        lazyAssignmentOperators: true);
  }

  void test_ampersand_eq() {
    _assertToken(TokenType.AMPERSAND_EQ, "&=");
  }

  void test_at() {
    _assertToken(TokenType.AT, "@");
  }

  void test_backping() {
    _assertToken(TokenType.BACKPING, "`");
  }

  void test_backslash() {
    _assertToken(TokenType.BACKSLASH, "\\");
  }

  void test_bang() {
    _assertToken(TokenType.BANG, "!");
  }

  void test_bang_eq() {
    _assertToken(TokenType.BANG_EQ, "!=");
  }

  void test_bar() {
    _assertToken(TokenType.BAR, "|");
  }

  void test_bar_bar() {
    _assertToken(TokenType.BAR_BAR, "||");
  }

  void test_bar_bar_eq() {
    _assertToken(TokenType.BAR_BAR_EQ, "||=", lazyAssignmentOperators: true);
  }

  void test_bar_eq() {
    _assertToken(TokenType.BAR_EQ, "|=");
  }

  void test_caret() {
    _assertToken(TokenType.CARET, "^");
  }

  void test_caret_eq() {
    _assertToken(TokenType.CARET_EQ, "^=");
  }

  void test_close_curly_bracket() {
    _assertToken(TokenType.CLOSE_CURLY_BRACKET, "}");
  }

  void test_close_paren() {
    _assertToken(TokenType.CLOSE_PAREN, ")");
  }

  void test_close_quare_bracket() {
    _assertToken(TokenType.CLOSE_SQUARE_BRACKET, "]");
  }

  void test_colon() {
    _assertToken(TokenType.COLON, ":");
  }

  void test_comma() {
    _assertToken(TokenType.COMMA, ",");
  }

  void test_comment_disabled_multi() {
    Scanner scanner =
        new _TestScanner(new CharSequenceReader("/* comment */ "));
    scanner.preserveComments = false;
    Token token = scanner.tokenize();
    expect(token, isNotNull);
    expect(token.precedingComments, isNull);
  }

  void test_comment_generic_method_type_assign() {
    _assertComment(TokenType.MULTI_LINE_COMMENT, "/*=comment*/");
    _assertComment(TokenType.GENERIC_METHOD_TYPE_ASSIGN, "/*=comment*/",
        genericMethodComments: true);
  }

  void test_comment_generic_method_type_list() {
    _assertComment(TokenType.MULTI_LINE_COMMENT, "/*<comment>*/");
    _assertComment(TokenType.GENERIC_METHOD_TYPE_LIST, "/*<comment>*/",
        genericMethodComments: true);
  }

  void test_comment_multi() {
    _assertComment(TokenType.MULTI_LINE_COMMENT, "/* comment */");
  }

  void test_comment_multi_consecutive_2() {
    Token token = _scan("/* x */ /* y */ z");
    expect(token.type, TokenType.IDENTIFIER);
    expect(token.precedingComments, isNotNull);
    expect(token.precedingComments.value(), "/* x */");
    expect(token.precedingComments.previous, isNull);
    expect(token.precedingComments.next, isNotNull);
    expect(token.precedingComments.next.value(), "/* y */");
    expect(
        token.precedingComments.next.previous, same(token.precedingComments));
    expect(token.precedingComments.next.next, isNull);
  }

  void test_comment_multi_consecutive_3() {
    Token token = _scan("/* x */ /* y */ /* z */ a");
    expect(token.type, TokenType.IDENTIFIER);
    expect(token.precedingComments, isNotNull);
    expect(token.precedingComments.value(), "/* x */");
    expect(token.precedingComments.previous, isNull);
    expect(token.precedingComments.next, isNotNull);
    expect(token.precedingComments.next.value(), "/* y */");
    expect(
        token.precedingComments.next.previous, same(token.precedingComments));
    expect(token.precedingComments.next.next, isNotNull);
    expect(token.precedingComments.next.next.value(), "/* z */");
    expect(token.precedingComments.next.next.previous,
        same(token.precedingComments.next));
    expect(token.precedingComments.next.next.next, isNull);
  }

  void test_comment_multi_lineEnds() {
    String code = r'''
/**
 * aa
 * bbb
 * c
 */''';
    _ErrorListener listener = new _ErrorListener();
    Scanner scanner = new _TestScanner(new CharSequenceReader(code), listener);
    scanner.tokenize();
    expect(
        scanner.lineStarts,
        equals(<int>[
          code.indexOf('/**'),
          code.indexOf(' * aa'),
          code.indexOf(' * bbb'),
          code.indexOf(' * c'),
          code.indexOf(' */')
        ]));
  }

  void test_comment_multi_unterminated() {
    _assertError(ScannerErrorCode.UNTERMINATED_MULTI_LINE_COMMENT, 3, "/* x");
  }

  void test_comment_nested() {
    _assertComment(
        TokenType.MULTI_LINE_COMMENT, "/* comment /* within a */ comment */");
  }

  void test_comment_single() {
    _assertComment(TokenType.SINGLE_LINE_COMMENT, "// comment");
  }

  void test_double_both_E() {
    _assertToken(TokenType.DOUBLE, "0.123E4");
  }

  void test_double_both_e() {
    _assertToken(TokenType.DOUBLE, "0.123e4");
  }

  void test_double_fraction() {
    _assertToken(TokenType.DOUBLE, ".123");
  }

  void test_double_fraction_E() {
    _assertToken(TokenType.DOUBLE, ".123E4");
  }

  void test_double_fraction_e() {
    _assertToken(TokenType.DOUBLE, ".123e4");
  }

  void test_double_missingDigitInExponent() {
    _assertError(ScannerErrorCode.MISSING_DIGIT, 1, "1e");
  }

  void test_double_whole_E() {
    _assertToken(TokenType.DOUBLE, "12E4");
  }

  void test_double_whole_e() {
    _assertToken(TokenType.DOUBLE, "12e4");
  }

  void test_eq() {
    _assertToken(TokenType.EQ, "=");
  }

  void test_eq_eq() {
    _assertToken(TokenType.EQ_EQ, "==");
  }

  void test_gt() {
    _assertToken(TokenType.GT, ">");
  }

  void test_gt_eq() {
    _assertToken(TokenType.GT_EQ, ">=");
  }

  void test_gt_gt() {
    _assertToken(TokenType.GT_GT, ">>");
  }

  void test_gt_gt_eq() {
    _assertToken(TokenType.GT_GT_EQ, ">>=");
  }

  void test_hash() {
    _assertToken(TokenType.HASH, "#");
  }

  void test_hexidecimal() {
    _assertToken(TokenType.HEXADECIMAL, "0x1A2B3C");
  }

  void test_hexidecimal_missingDigit() {
    _assertError(ScannerErrorCode.MISSING_HEX_DIGIT, 1, "0x");
  }

  void test_identifier() {
    _assertToken(TokenType.IDENTIFIER, "result");
  }

  void test_illegalChar_cyrillicLetter_middle() {
    _assertError(
        ScannerErrorCode.ILLEGAL_CHARACTER, 5, "Shche\u0433lov", [0x433]);
  }

  void test_illegalChar_cyrillicLetter_start() {
    _assertError(ScannerErrorCode.ILLEGAL_CHARACTER, 0, "\u0429", [0x429]);
  }

  void test_illegalChar_nbsp() {
    _assertError(ScannerErrorCode.ILLEGAL_CHARACTER, 0, "\u00A0", [0xa0]);
  }

  void test_illegalChar_notLetter() {
    _assertError(ScannerErrorCode.ILLEGAL_CHARACTER, 0, "\u0312", [0x312]);
  }

  void test_index() {
    _assertToken(TokenType.INDEX, "[]");
  }

  void test_index_eq() {
    _assertToken(TokenType.INDEX_EQ, "[]=");
  }

  void test_int() {
    _assertToken(TokenType.INT, "123");
  }

  void test_int_initialZero() {
    _assertToken(TokenType.INT, "0123");
  }

  void test_keyword_abstract() {
    _assertKeywordToken("abstract");
  }

  void test_keyword_as() {
    _assertKeywordToken("as");
  }

  void test_keyword_assert() {
    _assertKeywordToken("assert");
  }

  void test_keyword_break() {
    _assertKeywordToken("break");
  }

  void test_keyword_case() {
    _assertKeywordToken("case");
  }

  void test_keyword_catch() {
    _assertKeywordToken("catch");
  }

  void test_keyword_class() {
    _assertKeywordToken("class");
  }

  void test_keyword_const() {
    _assertKeywordToken("const");
  }

  void test_keyword_continue() {
    _assertKeywordToken("continue");
  }

  void test_keyword_default() {
    _assertKeywordToken("default");
  }

  void test_keyword_deferred() {
    _assertKeywordToken("deferred");
  }

  void test_keyword_do() {
    _assertKeywordToken("do");
  }

  void test_keyword_dynamic() {
    _assertKeywordToken("dynamic");
  }

  void test_keyword_else() {
    _assertKeywordToken("else");
  }

  void test_keyword_enum() {
    _assertKeywordToken("enum");
  }

  void test_keyword_export() {
    _assertKeywordToken("export");
  }

  void test_keyword_extends() {
    _assertKeywordToken("extends");
  }

  void test_keyword_factory() {
    _assertKeywordToken("factory");
  }

  void test_keyword_false() {
    _assertKeywordToken("false");
  }

  void test_keyword_final() {
    _assertKeywordToken("final");
  }

  void test_keyword_finally() {
    _assertKeywordToken("finally");
  }

  void test_keyword_for() {
    _assertKeywordToken("for");
  }

  void test_keyword_get() {
    _assertKeywordToken("get");
  }

  void test_keyword_if() {
    _assertKeywordToken("if");
  }

  void test_keyword_implements() {
    _assertKeywordToken("implements");
  }

  void test_keyword_import() {
    _assertKeywordToken("import");
  }

  void test_keyword_in() {
    _assertKeywordToken("in");
  }

  void test_keyword_is() {
    _assertKeywordToken("is");
  }

  void test_keyword_library() {
    _assertKeywordToken("library");
  }

  void test_keyword_new() {
    _assertKeywordToken("new");
  }

  void test_keyword_null() {
    _assertKeywordToken("null");
  }

  void test_keyword_operator() {
    _assertKeywordToken("operator");
  }

  void test_keyword_part() {
    _assertKeywordToken("part");
  }

  void test_keyword_rethrow() {
    _assertKeywordToken("rethrow");
  }

  void test_keyword_return() {
    _assertKeywordToken("return");
  }

  void test_keyword_set() {
    _assertKeywordToken("set");
  }

  void test_keyword_static() {
    _assertKeywordToken("static");
  }

  void test_keyword_super() {
    _assertKeywordToken("super");
  }

  void test_keyword_switch() {
    _assertKeywordToken("switch");
  }

  void test_keyword_this() {
    _assertKeywordToken("this");
  }

  void test_keyword_throw() {
    _assertKeywordToken("throw");
  }

  void test_keyword_true() {
    _assertKeywordToken("true");
  }

  void test_keyword_try() {
    _assertKeywordToken("try");
  }

  void test_keyword_typedef() {
    _assertKeywordToken("typedef");
  }

  void test_keyword_var() {
    _assertKeywordToken("var");
  }

  void test_keyword_void() {
    _assertKeywordToken("void");
  }

  void test_keyword_while() {
    _assertKeywordToken("while");
  }

  void test_keyword_with() {
    _assertKeywordToken("with");
  }

  void test_lt() {
    _assertToken(TokenType.LT, "<");
  }

  void test_lt_eq() {
    _assertToken(TokenType.LT_EQ, "<=");
  }

  void test_lt_lt() {
    _assertToken(TokenType.LT_LT, "<<");
  }

  void test_lt_lt_eq() {
    _assertToken(TokenType.LT_LT_EQ, "<<=");
  }

  void test_minus() {
    _assertToken(TokenType.MINUS, "-");
  }

  void test_minus_eq() {
    _assertToken(TokenType.MINUS_EQ, "-=");
  }

  void test_minus_minus() {
    _assertToken(TokenType.MINUS_MINUS, "--");
  }

  void test_open_curly_bracket() {
    _assertToken(TokenType.OPEN_CURLY_BRACKET, "{");
  }

  void test_open_paren() {
    _assertToken(TokenType.OPEN_PAREN, "(");
  }

  void test_open_square_bracket() {
    _assertToken(TokenType.OPEN_SQUARE_BRACKET, "[");
  }

  void test_openSquareBracket() {
    _assertToken(TokenType.OPEN_SQUARE_BRACKET, "[");
  }

  void test_percent() {
    _assertToken(TokenType.PERCENT, "%");
  }

  void test_percent_eq() {
    _assertToken(TokenType.PERCENT_EQ, "%=");
  }

  void test_period() {
    _assertToken(TokenType.PERIOD, ".");
  }

  void test_period_period() {
    _assertToken(TokenType.PERIOD_PERIOD, "..");
  }

  void test_period_period_period() {
    _assertToken(TokenType.PERIOD_PERIOD_PERIOD, "...");
  }

  void test_periodAfterNumberNotIncluded_identifier() {
    _assertTokens("42.isEven()", [
      new StringToken(TokenType.INT, "42", 0),
      new Token(TokenType.PERIOD, 2),
      new StringToken(TokenType.IDENTIFIER, "isEven", 3),
      new Token(TokenType.OPEN_PAREN, 9),
      new Token(TokenType.CLOSE_PAREN, 10)
    ]);
  }

  void test_periodAfterNumberNotIncluded_period() {
    _assertTokens("42..isEven()", [
      new StringToken(TokenType.INT, "42", 0),
      new Token(TokenType.PERIOD_PERIOD, 2),
      new StringToken(TokenType.IDENTIFIER, "isEven", 4),
      new Token(TokenType.OPEN_PAREN, 10),
      new Token(TokenType.CLOSE_PAREN, 11)
    ]);
  }

  void test_plus() {
    _assertToken(TokenType.PLUS, "+");
  }

  void test_plus_eq() {
    _assertToken(TokenType.PLUS_EQ, "+=");
  }

  void test_plus_plus() {
    _assertToken(TokenType.PLUS_PLUS, "++");
  }

  void test_question() {
    _assertToken(TokenType.QUESTION, "?");
  }

  void test_question_dot() {
    _assertToken(TokenType.QUESTION_PERIOD, "?.");
  }

  void test_question_question() {
    _assertToken(TokenType.QUESTION_QUESTION, "??");
  }

  void test_question_question_eq() {
    _assertToken(TokenType.QUESTION_QUESTION_EQ, "??=");
  }

  void test_scriptTag_withArgs() {
    _assertToken(TokenType.SCRIPT_TAG, "#!/bin/dart -debug");
  }

  void test_scriptTag_withoutSpace() {
    _assertToken(TokenType.SCRIPT_TAG, "#!/bin/dart");
  }

  void test_scriptTag_withSpace() {
    _assertToken(TokenType.SCRIPT_TAG, "#! /bin/dart");
  }

  void test_semicolon() {
    _assertToken(TokenType.SEMICOLON, ";");
  }

  void test_setSourceStart() {
    int offsetDelta = 42;
    _ErrorListener listener = new _ErrorListener();
    Scanner scanner =
        new _TestScanner(new SubSequenceReader("a", offsetDelta), listener);
    scanner.setSourceStart(3, 9);
    scanner.tokenize();
    List<int> lineStarts = scanner.lineStarts;
    expect(lineStarts, isNotNull);
    expect(lineStarts.length, 3);
    expect(lineStarts[2], 33);
  }

  void test_slash() {
    _assertToken(TokenType.SLASH, "/");
  }

  void test_slash_eq() {
    _assertToken(TokenType.SLASH_EQ, "/=");
  }

  void test_star() {
    _assertToken(TokenType.STAR, "*");
  }

  void test_star_eq() {
    _assertToken(TokenType.STAR_EQ, "*=");
  }

  void test_startAndEnd() {
    Token token = _scan("a");
    Token previous = token.previous;
    expect(previous.next, token);
    expect(previous.previous, previous);
    Token next = token.next;
    expect(next.next, next);
    expect(next.previous, token);
  }

  void test_string_multi_double() {
    _assertToken(TokenType.STRING, "\"\"\"line1\nline2\"\"\"");
  }

  void test_string_multi_embeddedQuotes() {
    _assertToken(TokenType.STRING, "\"\"\"line1\n\"\"\nline2\"\"\"");
  }

  void test_string_multi_embeddedQuotes_escapedChar() {
    _assertToken(TokenType.STRING, "\"\"\"a\"\"\\tb\"\"\"");
  }

  void test_string_multi_interpolation_block() {
    _assertTokens("\"Hello \${name}!\"", [
      new StringToken(TokenType.STRING, "\"Hello ", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_EXPRESSION, "\${", 7),
      new StringToken(TokenType.IDENTIFIER, "name", 9),
      new Token(TokenType.CLOSE_CURLY_BRACKET, 13),
      new StringToken(TokenType.STRING, "!\"", 14)
    ]);
  }

  void test_string_multi_interpolation_identifier() {
    _assertTokens("\"Hello \$name!\"", [
      new StringToken(TokenType.STRING, "\"Hello ", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_IDENTIFIER, "\$", 7),
      new StringToken(TokenType.IDENTIFIER, "name", 8),
      new StringToken(TokenType.STRING, "!\"", 12)
    ]);
  }

  void test_string_multi_single() {
    _assertToken(TokenType.STRING, "'''string'''");
  }

  void test_string_multi_slashEnter() {
    _assertToken(TokenType.STRING, "'''\\\n'''");
  }

  void test_string_multi_unterminated() {
    _assertErrorAndTokens(ScannerErrorCode.UNTERMINATED_STRING_LITERAL, 8,
        "'''string", [new StringToken(TokenType.STRING, "'''string", 0)]);
  }

  void test_string_multi_unterminated_interpolation_block() {
    _assertErrorAndTokens(
        ScannerErrorCode.UNTERMINATED_STRING_LITERAL, 8, "'''\${name", [
      new StringToken(TokenType.STRING, "'''", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_EXPRESSION, "\${", 3),
      new StringToken(TokenType.IDENTIFIER, "name", 5),
      new StringToken(TokenType.STRING, "", 9)
    ]);
  }

  void test_string_multi_unterminated_interpolation_identifier() {
    _assertErrorAndTokens(
        ScannerErrorCode.UNTERMINATED_STRING_LITERAL, 7, "'''\$name", [
      new StringToken(TokenType.STRING, "'''", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_IDENTIFIER, "\$", 3),
      new StringToken(TokenType.IDENTIFIER, "name", 4),
      new StringToken(TokenType.STRING, "", 8)
    ]);
  }

  void test_string_raw_multi_double() {
    _assertToken(TokenType.STRING, "r\"\"\"line1\nline2\"\"\"");
  }

  void test_string_raw_multi_single() {
    _assertToken(TokenType.STRING, "r'''string'''");
  }

  void test_string_raw_multi_unterminated() {
    String source = "r'''string";
    _assertErrorAndTokens(ScannerErrorCode.UNTERMINATED_STRING_LITERAL, 9,
        source, [new StringToken(TokenType.STRING, source, 0)]);
  }

  void test_string_raw_simple_double() {
    _assertToken(TokenType.STRING, "r\"string\"");
  }

  void test_string_raw_simple_single() {
    _assertToken(TokenType.STRING, "r'string'");
  }

  void test_string_raw_simple_unterminated_eof() {
    String source = "r'string";
    _assertErrorAndTokens(ScannerErrorCode.UNTERMINATED_STRING_LITERAL, 7,
        source, [new StringToken(TokenType.STRING, source, 0)]);
  }

  void test_string_raw_simple_unterminated_eol() {
    String source = "r'string";
    _assertErrorAndTokens(ScannerErrorCode.UNTERMINATED_STRING_LITERAL, 8,
        "$source\n", [new StringToken(TokenType.STRING, source, 0)]);
  }

  void test_string_simple_double() {
    _assertToken(TokenType.STRING, "\"string\"");
  }

  void test_string_simple_escapedDollar() {
    _assertToken(TokenType.STRING, "'a\\\$b'");
  }

  void test_string_simple_interpolation_adjacentIdentifiers() {
    _assertTokens("'\$a\$b'", [
      new StringToken(TokenType.STRING, "'", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_IDENTIFIER, "\$", 1),
      new StringToken(TokenType.IDENTIFIER, "a", 2),
      new StringToken(TokenType.STRING, "", 3),
      new StringToken(TokenType.STRING_INTERPOLATION_IDENTIFIER, "\$", 3),
      new StringToken(TokenType.IDENTIFIER, "b", 4),
      new StringToken(TokenType.STRING, "'", 5)
    ]);
  }

  void test_string_simple_interpolation_block() {
    _assertTokens("'Hello \${name}!'", [
      new StringToken(TokenType.STRING, "'Hello ", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_EXPRESSION, "\${", 7),
      new StringToken(TokenType.IDENTIFIER, "name", 9),
      new Token(TokenType.CLOSE_CURLY_BRACKET, 13),
      new StringToken(TokenType.STRING, "!'", 14)
    ]);
  }

  void test_string_simple_interpolation_blockWithNestedMap() {
    _assertTokens("'a \${f({'b' : 'c'})} d'", [
      new StringToken(TokenType.STRING, "'a ", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_EXPRESSION, "\${", 3),
      new StringToken(TokenType.IDENTIFIER, "f", 5),
      new Token(TokenType.OPEN_PAREN, 6),
      new Token(TokenType.OPEN_CURLY_BRACKET, 7),
      new StringToken(TokenType.STRING, "'b'", 8),
      new Token(TokenType.COLON, 12),
      new StringToken(TokenType.STRING, "'c'", 14),
      new Token(TokenType.CLOSE_CURLY_BRACKET, 17),
      new Token(TokenType.CLOSE_PAREN, 18),
      new Token(TokenType.CLOSE_CURLY_BRACKET, 19),
      new StringToken(TokenType.STRING, " d'", 20)
    ]);
  }

  void test_string_simple_interpolation_firstAndLast() {
    _assertTokens("'\$greeting \$name'", [
      new StringToken(TokenType.STRING, "'", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_IDENTIFIER, "\$", 1),
      new StringToken(TokenType.IDENTIFIER, "greeting", 2),
      new StringToken(TokenType.STRING, " ", 10),
      new StringToken(TokenType.STRING_INTERPOLATION_IDENTIFIER, "\$", 11),
      new StringToken(TokenType.IDENTIFIER, "name", 12),
      new StringToken(TokenType.STRING, "'", 16)
    ]);
  }

  void test_string_simple_interpolation_identifier() {
    _assertTokens("'Hello \$name!'", [
      new StringToken(TokenType.STRING, "'Hello ", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_IDENTIFIER, "\$", 7),
      new StringToken(TokenType.IDENTIFIER, "name", 8),
      new StringToken(TokenType.STRING, "!'", 12)
    ]);
  }

  void test_string_simple_interpolation_missingIdentifier() {
    _assertTokens("'\$x\$'", [
      new StringToken(TokenType.STRING, "'", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_IDENTIFIER, "\$", 1),
      new StringToken(TokenType.IDENTIFIER, "x", 2),
      new StringToken(TokenType.STRING, "", 3),
      new StringToken(TokenType.STRING_INTERPOLATION_IDENTIFIER, "\$", 3),
      new StringToken(TokenType.STRING, "'", 4)
    ]);
  }

  void test_string_simple_interpolation_nonIdentifier() {
    _assertTokens("'\$1'", [
      new StringToken(TokenType.STRING, "'", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_IDENTIFIER, "\$", 1),
      new StringToken(TokenType.STRING, "1'", 2)
    ]);
  }

  void test_string_simple_single() {
    _assertToken(TokenType.STRING, "'string'");
  }

  void test_string_simple_unterminated_eof() {
    String source = "'string";
    _assertErrorAndTokens(ScannerErrorCode.UNTERMINATED_STRING_LITERAL, 6,
        source, [new StringToken(TokenType.STRING, source, 0)]);
  }

  void test_string_simple_unterminated_eol() {
    String source = "'string";
    _assertErrorAndTokens(ScannerErrorCode.UNTERMINATED_STRING_LITERAL, 7,
        "$source\r", [new StringToken(TokenType.STRING, source, 0)]);
  }

  void test_string_simple_unterminated_interpolation_block() {
    _assertErrorAndTokens(
        ScannerErrorCode.UNTERMINATED_STRING_LITERAL, 6, "'\${name", [
      new StringToken(TokenType.STRING, "'", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_EXPRESSION, "\${", 1),
      new StringToken(TokenType.IDENTIFIER, "name", 3),
      new StringToken(TokenType.STRING, "", 7)
    ]);
  }

  void test_string_simple_unterminated_interpolation_identifier() {
    _assertErrorAndTokens(
        ScannerErrorCode.UNTERMINATED_STRING_LITERAL, 5, "'\$name", [
      new StringToken(TokenType.STRING, "'", 0),
      new StringToken(TokenType.STRING_INTERPOLATION_IDENTIFIER, "\$", 1),
      new StringToken(TokenType.IDENTIFIER, "name", 2),
      new StringToken(TokenType.STRING, "", 6)
    ]);
  }

  void test_tilde() {
    _assertToken(TokenType.TILDE, "~");
  }

  void test_tilde_slash() {
    _assertToken(TokenType.TILDE_SLASH, "~/");
  }

  void test_tilde_slash_eq() {
    _assertToken(TokenType.TILDE_SLASH_EQ, "~/=");
  }

  void test_unclosedPairInInterpolation() {
    _ErrorListener listener = new _ErrorListener();
    _scanWithListener("'\${(}'", listener);
  }

  void _assertComment(TokenType commentType, String source,
      {bool genericMethodComments: false}) {
    //
    // Test without a trailing end-of-line marker
    //
    Token token = _scan(source, genericMethodComments: genericMethodComments);
    expect(token, isNotNull);
    expect(token.type, TokenType.EOF);
    Token comment = token.precedingComments;
    expect(comment, isNotNull);
    expect(comment.type, commentType);
    expect(comment.offset, 0);
    expect(comment.length, source.length);
    expect(comment.lexeme, source);
    //
    // Test with a trailing end-of-line marker
    //
    token = _scan("$source\n", genericMethodComments: genericMethodComments);
    expect(token, isNotNull);
    expect(token.type, TokenType.EOF);
    comment = token.precedingComments;
    expect(comment, isNotNull);
    expect(comment.type, commentType);
    expect(comment.offset, 0);
    expect(comment.length, source.length);
    expect(comment.lexeme, source);
  }

  /**
   * Assert that scanning the given [source] produces an error with the given
   * code.
   *
   * [expectedError] the error that should be produced
   * [expectedOffset] the string offset that should be associated with the error
   * [source] the source to be scanned to produce the error
   */
  void _assertError(
      ScannerErrorCode expectedError, int expectedOffset, String source,
      [List<Object> arguments]) {
    _ErrorListener listener = new _ErrorListener();
    _scanWithListener(source, listener);
    listener.assertErrors(
        [new _TestError(expectedOffset, 1, expectedError, arguments)]);
  }

  /**
   * Assert that scanning the given [source] produces an error with the given
   * code, and also produces the given tokens.
   *
   * [expectedError] the error that should be produced
   * [expectedOffset] the string offset that should be associated with the error
   * [source] the source to be scanned to produce the error
   * [expectedTokens] the tokens that are expected to be in the source
   */
  void _assertErrorAndTokens(ScannerErrorCode expectedError, int expectedOffset,
      String source, List<Token> expectedTokens) {
    _ErrorListener listener = new _ErrorListener();
    Token token = _scanWithListener(source, listener);
    listener
        .assertErrors([new _TestError(expectedOffset, 1, expectedError, null)]);
    _checkTokens(token, expectedTokens);
  }

  /**
   * Assert that when scanned the given [source] contains a single keyword token
   * with the same lexeme as the original source.
   */
  void _assertKeywordToken(String source) {
    Token token = _scan(source);
    expect(token, isNotNull);
    expect(token.type, TokenType.KEYWORD);
    expect(token.offset, 0);
    expect(token.length, source.length);
    expect(token.lexeme, source);
    Object value = token.value();
    expect(value is Keyword, isTrue);
    expect((value as Keyword).syntax, source);
    token = _scan(" $source ");
    expect(token, isNotNull);
    expect(token.type, TokenType.KEYWORD);
    expect(token.offset, 1);
    expect(token.length, source.length);
    expect(token.lexeme, source);
    value = token.value();
    expect(value is Keyword, isTrue);
    expect((value as Keyword).syntax, source);
    expect(token.next.type, TokenType.EOF);
  }

  /**
   * Assert that the token scanned from the given [source] has the
   * [expectedType].
   */
  Token _assertToken(TokenType expectedType, String source,
      {bool lazyAssignmentOperators: false}) {
    Token originalToken =
        _scan(source, lazyAssignmentOperators: lazyAssignmentOperators);
    expect(originalToken, isNotNull);
    expect(originalToken.type, expectedType);
    expect(originalToken.offset, 0);
    expect(originalToken.length, source.length);
    expect(originalToken.lexeme, source);
    if (expectedType == TokenType.SCRIPT_TAG) {
      // Adding space before the script tag is not allowed, and adding text at
      // the end changes nothing.
      return originalToken;
    } else if (expectedType == TokenType.SINGLE_LINE_COMMENT) {
      // Adding space to an end-of-line comment changes the comment.
      Token tokenWithSpaces =
          _scan(" $source", lazyAssignmentOperators: lazyAssignmentOperators);
      expect(tokenWithSpaces, isNotNull);
      expect(tokenWithSpaces.type, expectedType);
      expect(tokenWithSpaces.offset, 1);
      expect(tokenWithSpaces.length, source.length);
      expect(tokenWithSpaces.lexeme, source);
      return originalToken;
    } else if (expectedType == TokenType.INT ||
        expectedType == TokenType.DOUBLE) {
      Token tokenWithLowerD =
          _scan("${source}d", lazyAssignmentOperators: lazyAssignmentOperators);
      expect(tokenWithLowerD, isNotNull);
      expect(tokenWithLowerD.type, expectedType);
      expect(tokenWithLowerD.offset, 0);
      expect(tokenWithLowerD.length, source.length);
      expect(tokenWithLowerD.lexeme, source);
      Token tokenWithUpperD =
          _scan("${source}D", lazyAssignmentOperators: lazyAssignmentOperators);
      expect(tokenWithUpperD, isNotNull);
      expect(tokenWithUpperD.type, expectedType);
      expect(tokenWithUpperD.offset, 0);
      expect(tokenWithUpperD.length, source.length);
      expect(tokenWithUpperD.lexeme, source);
    }
    Token tokenWithSpaces =
        _scan(" $source ", lazyAssignmentOperators: lazyAssignmentOperators);
    expect(tokenWithSpaces, isNotNull);
    expect(tokenWithSpaces.type, expectedType);
    expect(tokenWithSpaces.offset, 1);
    expect(tokenWithSpaces.length, source.length);
    expect(tokenWithSpaces.lexeme, source);
    expect(originalToken.next.type, TokenType.EOF);
    return originalToken;
  }

  /**
   * Assert that when scanned the given [source] contains a sequence of tokens
   * identical to the given list of [expectedTokens].
   */
  void _assertTokens(String source, List<Token> expectedTokens) {
    Token token = _scan(source);
    _checkTokens(token, expectedTokens);
  }

  void _checkTokens(Token firstToken, List<Token> expectedTokens) {
    expect(firstToken, isNotNull);
    Token token = firstToken;
    for (int i = 0; i < expectedTokens.length; i++) {
      Token expectedToken = expectedTokens[i];
      expect(token.type, expectedToken.type, reason: "Wrong type for token $i");
      expect(token.offset, expectedToken.offset,
          reason: "Wrong offset for token $i");
      expect(token.length, expectedToken.length,
          reason: "Wrong length for token $i");
      expect(token.lexeme, expectedToken.lexeme,
          reason: "Wrong lexeme for token $i");
      token = token.next;
      expect(token, isNotNull);
    }
    expect(token.type, TokenType.EOF);
  }

  Token _scan(String source,
      {bool genericMethodComments: false,
      bool lazyAssignmentOperators: false}) {
    _ErrorListener listener = new _ErrorListener();
    Token token = _scanWithListener(source, listener,
        genericMethodComments: genericMethodComments,
        lazyAssignmentOperators: lazyAssignmentOperators);
    listener.assertNoErrors();
    return token;
  }

  Token _scanWithListener(String source, _ErrorListener listener,
      {bool genericMethodComments: false, bool lazyAssignmentOperators: false});
}

@reflectiveTest
class TokenTypeTest {
  void test_isOperator() {
    expect(TokenType.AMPERSAND.isOperator, isTrue);
    expect(TokenType.AMPERSAND_AMPERSAND.isOperator, isTrue);
    expect(TokenType.AMPERSAND_EQ.isOperator, isTrue);
    expect(TokenType.BANG.isOperator, isTrue);
    expect(TokenType.BANG_EQ.isOperator, isTrue);
    expect(TokenType.BAR.isOperator, isTrue);
    expect(TokenType.BAR_BAR.isOperator, isTrue);
    expect(TokenType.BAR_EQ.isOperator, isTrue);
    expect(TokenType.CARET.isOperator, isTrue);
    expect(TokenType.CARET_EQ.isOperator, isTrue);
    expect(TokenType.EQ.isOperator, isTrue);
    expect(TokenType.EQ_EQ.isOperator, isTrue);
    expect(TokenType.GT.isOperator, isTrue);
    expect(TokenType.GT_EQ.isOperator, isTrue);
    expect(TokenType.GT_GT.isOperator, isTrue);
    expect(TokenType.GT_GT_EQ.isOperator, isTrue);
    expect(TokenType.INDEX.isOperator, isTrue);
    expect(TokenType.INDEX_EQ.isOperator, isTrue);
    expect(TokenType.IS.isOperator, isTrue);
    expect(TokenType.LT.isOperator, isTrue);
    expect(TokenType.LT_EQ.isOperator, isTrue);
    expect(TokenType.LT_LT.isOperator, isTrue);
    expect(TokenType.LT_LT_EQ.isOperator, isTrue);
    expect(TokenType.MINUS.isOperator, isTrue);
    expect(TokenType.MINUS_EQ.isOperator, isTrue);
    expect(TokenType.MINUS_MINUS.isOperator, isTrue);
    expect(TokenType.PERCENT.isOperator, isTrue);
    expect(TokenType.PERCENT_EQ.isOperator, isTrue);
    expect(TokenType.PERIOD_PERIOD.isOperator, isTrue);
    expect(TokenType.PLUS.isOperator, isTrue);
    expect(TokenType.PLUS_EQ.isOperator, isTrue);
    expect(TokenType.PLUS_PLUS.isOperator, isTrue);
    expect(TokenType.QUESTION.isOperator, isTrue);
    expect(TokenType.SLASH.isOperator, isTrue);
    expect(TokenType.SLASH_EQ.isOperator, isTrue);
    expect(TokenType.STAR.isOperator, isTrue);
    expect(TokenType.STAR_EQ.isOperator, isTrue);
    expect(TokenType.TILDE.isOperator, isTrue);
    expect(TokenType.TILDE_SLASH.isOperator, isTrue);
    expect(TokenType.TILDE_SLASH_EQ.isOperator, isTrue);
  }

  void test_isUserDefinableOperator() {
    expect(TokenType.AMPERSAND.isUserDefinableOperator, isTrue);
    expect(TokenType.BAR.isUserDefinableOperator, isTrue);
    expect(TokenType.CARET.isUserDefinableOperator, isTrue);
    expect(TokenType.EQ_EQ.isUserDefinableOperator, isTrue);
    expect(TokenType.GT.isUserDefinableOperator, isTrue);
    expect(TokenType.GT_EQ.isUserDefinableOperator, isTrue);
    expect(TokenType.GT_GT.isUserDefinableOperator, isTrue);
    expect(TokenType.INDEX.isUserDefinableOperator, isTrue);
    expect(TokenType.INDEX_EQ.isUserDefinableOperator, isTrue);
    expect(TokenType.LT.isUserDefinableOperator, isTrue);
    expect(TokenType.LT_EQ.isUserDefinableOperator, isTrue);
    expect(TokenType.LT_LT.isUserDefinableOperator, isTrue);
    expect(TokenType.MINUS.isUserDefinableOperator, isTrue);
    expect(TokenType.PERCENT.isUserDefinableOperator, isTrue);
    expect(TokenType.PLUS.isUserDefinableOperator, isTrue);
    expect(TokenType.SLASH.isUserDefinableOperator, isTrue);
    expect(TokenType.STAR.isUserDefinableOperator, isTrue);
    expect(TokenType.TILDE.isUserDefinableOperator, isTrue);
    expect(TokenType.TILDE_SLASH.isUserDefinableOperator, isTrue);
  }
}

class _ErrorListener {
  final errors = <_TestError>[];

  void assertErrors(List<_TestError> expectedErrors) {
    expect(errors, unorderedEquals(expectedErrors));
  }

  void assertNoErrors() {
    assertErrors([]);
  }
}

class _TestError {
  final int offset;
  final int length;
  final ErrorCode errorCode;
  final List<Object> arguments;

  _TestError(this.offset, this.length, this.errorCode, this.arguments);

  @override
  get hashCode {
    var h = new JenkinsSmiHash()..add(offset)..add(length)..add(errorCode);
    if (arguments != null) {
      for (Object argument in arguments) {
        h.add(argument);
      }
    }
    return h.hashCode;
  }

  @override
  operator ==(Object other) {
    if (other is _TestError &&
        offset == other.offset &&
        length == other.length &&
        errorCode == other.errorCode) {
      if (arguments == null) return other.arguments == null;
      if (other.arguments == null) return false;
      if (arguments.length != other.arguments.length) return false;
      for (int i = 0; i < arguments.length; i++) {
        if (arguments[i] != other.arguments[i]) return false;
      }
      return true;
    }
    return false;
  }

  @override
  toString() {
    var end = offset + length;
    var argString = arguments == null ? '' : '(${arguments.join(', ')})';
    return 'Error($offset..$end, $errorCode$argString)';
  }
}

class _TestScanner extends Scanner {
  final _ErrorListener listener;

  _TestScanner(CharacterReader reader, [this.listener]) : super(reader);

  @override
  void reportError(
      ScannerErrorCode errorCode, int offset, List<Object> arguments) {
    if (listener != null) {
      listener.errors.add(new _TestError(offset, 1, errorCode, arguments));
    }
  }
}
