#include "dtext.h"

#include <ruby.h>
#include <ruby/encoding.h>

static VALUE cDText = Qnil;
static VALUE cDTextError = Qnil;

static VALUE c_parse(VALUE self, VALUE input, VALUE f_inline, VALUE f_allow_color, VALUE f_max_thumbs, VALUE base_url) {
  if (NIL_P(input)) {
    return Qnil;
  }

  StringValue(input);
  StateMachine sm = init_machine(RSTRING_PTR(input), RSTRING_LEN(input));
  sm.f_inline = RTEST(f_inline);
  sm.allow_color = RTEST(f_allow_color);
  sm.max_thumbs = FIX2LONG(f_max_thumbs);

  if (!NIL_P(base_url)) {
    sm.base_url = StringValueCStr(base_url); // base_url.to_str # raises ArgumentError if base_url contains null bytes.
  }

  if (!parse_helper(&sm)) {
    rb_raise(cDTextError, "%s", sm.error.c_str());
  }

  VALUE retStr = rb_utf8_str_new(sm.output.c_str(), sm.output.size());
  VALUE retPostIds = rb_ary_new_capa(sm.posts.size());
  for (long post_id : sm.posts) {
    rb_ary_push(retPostIds, LONG2FIX(post_id));
  }

  VALUE ret = rb_ary_new_capa(2);
  rb_ary_push(ret, retStr);
  rb_ary_push(ret, retPostIds);

  return ret;
}

extern "C" void Init_dtext() {
  cDText = rb_define_module("DText");
  cDTextError = rb_define_class_under(cDText, "Error", rb_eStandardError);
  rb_define_singleton_method(cDText, "c_parse", c_parse, 5);
}