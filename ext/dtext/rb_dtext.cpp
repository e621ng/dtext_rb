#include "dtext.h"

#include <glib.h>
#include <ruby.h>
#include <ruby/encoding.h>

static VALUE mDText = Qnil;
static VALUE mDTextError = Qnil;

static VALUE c_parse(VALUE self, VALUE input, VALUE f_inline, VALUE f_allow_color, VALUE f_max_thumbs, VALUE base_url) {
  if (NIL_P(input)) {
    return Qnil;
  }

  StringValue(input);
  StateMachine* sm = init_machine(RSTRING_PTR(input), RSTRING_LEN(input));
  sm->f_inline = RTEST(f_inline);
  sm->allow_color = RTEST(f_allow_color);
  sm->max_thumbs = FIX2LONG(f_max_thumbs);

  if (!NIL_P(base_url)) {
    sm->base_url = StringValueCStr(base_url); // base_url.to_str # raises ArgumentError if base_url contains null bytes.
  }

  if (!parse_helper(sm)) {
    GError* error = g_error_copy(sm->error);
    free_machine(sm);
    rb_raise(mDTextError, "%s", error->message);
  }

  VALUE retStr = rb_utf8_str_new(sm->output->str, sm->output->len);
  size_t post_size = sm->posts->len;
  VALUE retPostIds = rb_ary_new_capa(post_size);
  for(int i = post_size-1; i >= 0; --i) {
    rb_ary_push(retPostIds, LONG2FIX(g_array_index(sm->posts, long, i)));
  }
  VALUE ret = rb_ary_new_capa(2);
  rb_ary_push(ret, retStr);
  rb_ary_push(ret, retPostIds);

  free_machine(sm);

  return ret;
}

extern "C" void Init_dtext() {
  mDText = rb_define_module("DText");
  mDTextError = rb_define_class_under(mDText, "Error", rb_eStandardError);
  rb_define_singleton_method(mDText, "c_parse", c_parse, 5);
}
