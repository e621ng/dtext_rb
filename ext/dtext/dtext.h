#ifndef DTEXT_H
#define DTEXT_H

#include <string>
#include <vector>
#include <stdexcept>

typedef enum element_t {
  DSTACK_EMPTY = 0,
  BLOCK_P,
  BLOCK_QUOTE,
  BLOCK_SECTION,
  BLOCK_SPOILER,
  BLOCK_CODE,
  BLOCK_TABLE,
  BLOCK_THEAD,
  BLOCK_TBODY,
  BLOCK_UL,
  BLOCK_LI,
  BLOCK_TR,
  BLOCK_TH,
  BLOCK_TD,
  BLOCK_H1,
  BLOCK_H2,
  BLOCK_H3,
  BLOCK_H4,
  BLOCK_H5,
  BLOCK_H6,
  INLINE_B,
  INLINE_I,
  INLINE_U,
  INLINE_S,
  INLINE_SUP,
  INLINE_SUB,
  INLINE_COLOR,
  INLINE_SPOILER,
} element_t;

class DTextError : public std::runtime_error {
  using std::runtime_error::runtime_error;
};

struct DTextOptions {
  bool f_inline = false;
  bool allow_color = false;
  int max_thumbs = 25;
  std::string base_url;
};

struct DTextResult {
  std::string dtext;
  std::vector<long> posts;
};

class StateMachine {
public:
  static DTextResult parse_dtext(const std::string_view dtext, DTextOptions options);
  static std::string parse_basic_inline(const std::string_view dtext);

  DTextOptions options;

  size_t top;
  int cs;
  int act = 0;
  const char * p = NULL;
  const char * pb = NULL;
  const char * pe = NULL;
  const char * eof = NULL;
  const char * ts = NULL;
  const char * te = NULL;
  const char * a1 = NULL;
  const char * a2 = NULL;
  const char * b1 = NULL;
  const char * b2 = NULL;

  bool header_mode = false;

  std::vector<long> posts;
  std::string output;
  std::vector<int> stack;
  std::vector<element_t> dstack;

private:
  StateMachine(const std::string_view dtext, int initial_state, const DTextOptions options);
  DTextResult parse();
};

#endif
