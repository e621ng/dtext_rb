#ifndef DTEXT_H
#define DTEXT_H

#include <string>
#include <vector>

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
  BLOCK_TN,
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
  INLINE_TN,
  INLINE_SUP,
  INLINE_SUB,
  INLINE_COLOR,
  INLINE_SPOILER,
} element_t;

typedef struct StateMachine {
  bool f_inline;
  bool allow_color;
  int max_thumbs;
  std::string base_url;

  size_t top;
  int cs;
  int act;
  const char * p;
  const char * pb;
  const char * pe;
  const char * eof;
  const char * ts;
  const char * te;

  const char * a1;
  const char * a2;
  const char * b1;
  const char * b2;
  bool list_mode;
  bool header_mode;
  int list_nest;
  std::vector<long> posts;
  std::string output;
  std::vector<int> stack;
  std::vector<element_t> dstack;
  std::string  error;
} StateMachine;

StateMachine init_machine(const char * src, size_t len);

bool parse_helper(StateMachine* sm);
std::string parse_basic_inline(const char* dtext, const ssize_t length);

#endif
