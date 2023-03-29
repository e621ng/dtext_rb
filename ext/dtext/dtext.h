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

class DTextError : public std::runtime_error {
  using std::runtime_error::runtime_error;
};

struct DTextOptions {
  bool f_inline = false;
  bool allow_color = false;
  int max_thumbs = 25;
  std::string base_url;
};

typedef struct StateMachine {
  DTextOptions options;

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
} StateMachine;

StateMachine init_machine(const char * src, size_t len);

void parse_helper(StateMachine* sm);
std::string parse_basic_inline(const char* dtext, const ssize_t length);

#endif
