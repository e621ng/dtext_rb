#include "dtext.h"

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <glib.h>

static const size_t MAX_STACK_DEPTH = 512;

typedef enum element_t {
  QUEUE_EMPTY = 0,
  BLOCK_P = 1,
  INLINE_SPOILER = 2,
  BLOCK_SPOILER = 3,
  BLOCK_QUOTE = 4,
  BLOCK_SECTION = 5,
  BLOCK_NODTEXT = 6,
  BLOCK_CODE = 7,
  BLOCK_TD = 8,
  INLINE_NODTEXT = 9,
  INLINE_B = 10,
  INLINE_I = 11,
  INLINE_U = 12,
  INLINE_S = 13,
  INLINE_TN = 14,
  BLOCK_TN = 15,
  BLOCK_TABLE = 16,
  BLOCK_THEAD = 17,
  BLOCK_TBODY = 18,
  BLOCK_TR = 19,
  BLOCK_UL = 20,
  BLOCK_LI = 21,
  BLOCK_TH = 22,
  BLOCK_H1 = 23,
  BLOCK_H2 = 24,
  BLOCK_H3 = 25,
  BLOCK_H4 = 26,
  BLOCK_H5 = 27,
  BLOCK_H6 = 28,
  INLINE_SUP = 31,
  INLINE_SUB = 32,
  INLINE_COLOR = 33
} element_t;

%%{
machine dtext;

access sm->;
variable p sm->p;
variable pe sm->pe;
variable eof sm->eof;
variable top sm->top;
variable ts sm->ts;
variable te sm->te;
variable act sm->act;
variable stack ((int *)sm->stack->data);

prepush {
  size_t len = sm->stack->len;

  if (len > MAX_STACK_DEPTH) {
    g_set_error_literal(&sm->error, DTEXT_PARSE_ERROR, DTEXT_PARSE_ERROR_DEPTH_EXCEEDED, "too many nested elements");
    fbreak;
  }

  if (sm->top >= len) {
    g_debug("growing sm->stack %zi\n", len + 16);
    sm->stack = g_array_set_size(sm->stack, len + 16);
  }
}

action mark_a1 {
  sm->a1 = sm->p;
}

action mark_a2 {
  sm->a2 = sm->p;
}

action mark_b1 {
  sm->b1 = sm->p;
}

action mark_b2 {
  sm->b2 = sm->p;
}

newline = '\r\n' | '\n';

nonnewline = any - (newline | '\r');
nonquote = ^'"';
nonbracket = ^']';
nonpipe = ^'|';
nonpipebracket = nonpipe & nonbracket;
noncurly = ^'}';
nonpipecurly = nonpipe & noncurly;

utf8graph = (0x00..0x7F) & graph
          | 0xC2..0xDF 0x80..0xBF
          | 0xE0..0xEF 0x80..0xBF 0x80..0xBF
          | 0xF0..0xF4 0x80..0xBF 0x80..0xBF 0x80..0xBF;

url = 'http'i 's'i? '://' utf8graph+;
delimited_url = '<' url :>> '>';
internal_url = [/#] utf8graph+;
basic_textile_link = '"' nonquote+ >mark_a1 '"' >mark_a2 ':' (url | internal_url) >mark_b1 @mark_b2;
bracketed_textile_link = '"' nonquote+ >mark_a1 '"' >mark_a2 ':[' (url | internal_url) >mark_b1 @mark_b2 :>> ']';

basic_wiki_link = '[[' (nonbracket nonpipebracket*) >mark_a1 %mark_a2 ']]';
aliased_wiki_link = '[[' nonpipebracket+ >mark_a1 %mark_a2 '|' nonpipebracket+ >mark_b1 %mark_b2 ']]';

basic_post_search_link = '{{' (noncurly nonpipecurly*) >mark_a1 %mark_a2 '}}';
aliased_post_search_link = '{{' nonpipecurly+ >mark_a1 %mark_a2 '|' nonpipecurly+ >mark_b1 %mark_b2 '}}';

spoilers_open = '[spoiler'i 's'i? ']';
spoilers_close = '[/spoiler'i 's'i? ']';

color_open = '[color='i ([a-z]+|'#'i[0-9a-fA-F]{3,6}) >mark_a1 %mark_a2 ']';
color_typed = '[color='i ('art'i('ist'i)?|'char'i('acter'i)?|'copy'i('right'i)?|'spec'i('ies'i)?|'inv'i('alid'i)?|'meta'i|'lore'i) >mark_a1 %mark_a2 ']';
color_close = '[/color]'i;

id = digit+ >mark_a1 %mark_a2;
page = digit+ >mark_b1 %mark_b2;

post_id = 'post #'i id;
post_changes_for_id = 'post changes #'i id;
thumb_id = 'thumb #'i id;
post_flag_id = 'flag #'i id;
note_id = 'note #'i id;
forum_post_id = 'forum #'i id;
forum_topic_id = 'topic #'i id;
comment_id = 'comment #'i id;
pool_id = 'pool #'i id;
user_id = 'user #'i id;
artist_id = 'artist #'i id;
ban_id = 'ban #'i id;
bulk_update_request_id = 'bur #'i id;
tag_alias_id = 'alias #'i id;
tag_implication_id = 'implication #'i id;
mod_action_id = 'mod action #'i id;
user_feedback_id = 'record #'i id;
wiki_page_id = 'wiki #'i id;
set_id = 'set #'i id;
blip_id = 'blip #'i id;
takedown_id = 'take'i ' 'i? 'down 'i 'request 'i? '#'i id;
ticket_id = 'ticket #'i id;

ws = ' ' | '\t';
nonperiod = graph - ('.' | '"');
header = 'h'i [123456] >mark_a1 %mark_a2 '.' ws*;
header_with_id = 'h'i [123456] >mark_a1 %mark_a2 '#' nonperiod+ >mark_b1 %mark_b2 '.' ws*;
aliased_section = '[section='i (nonbracket+ >mark_a1 %mark_a2) ']';
aliased_section_expanded = '[section,expanded='i (nonbracket+ >mark_a1 %mark_a2) ']';
internal_anchor = '[#' (nonbracket+ >mark_a1 %mark_a2) ']';

list_item = '*'+ >mark_a1 %mark_a2 ws+ nonnewline+ >mark_b1 %mark_b2;

basic_inline := |*
  '[b]'i    => { dstack_open_inline(sm,  INLINE_B, "<strong>"); };
  '[/b]'i   => { dstack_close_inline(sm, INLINE_B, "</strong>"); };
  '[i]'i    => { dstack_open_inline(sm,  INLINE_I, "<em>"); };
  '[/i]'i   => { dstack_close_inline(sm, INLINE_I, "</em>"); };
  '[s]'i    => { dstack_open_inline(sm,  INLINE_S, "<s>"); };
  '[/s]'i   => { dstack_close_inline(sm, INLINE_S, "</s>"); };
  '[u]'i    => { dstack_open_inline(sm,  INLINE_U, "<u>"); };
  '[/u]'i   => { dstack_close_inline(sm, INLINE_U, "</u>"); };
  '[sup]'i  => { dstack_open_inline(sm, INLINE_SUP, "<sup>"); };
  '[/sup]'i => { dstack_close_inline(sm, INLINE_SUP, "</sup>"); };
  '[sub]'i  => { dstack_open_inline(sm, INLINE_SUB, "<sub>"); };
  '[/sub]'i => { dstack_close_inline(sm, INLINE_SUB, "</sub>"); };
  any => { append_c_html_escaped(sm, fc); };
*|;

inline := |*
  '\\`' => {
    append(sm, "`");
  };

  '`' => {
    append(sm, "<span class=\"inline-code\">");
    fcall inline_code;
  };

  internal_anchor => {
    append(sm, "<a id=\"");
    g_autofree gchar* lowercased_tag = g_utf8_strdown(sm->a1, sm->a2-sm->a1);
    const size_t tag_len = sm->a2 - sm->a1;
    append_segment_uri_escaped(sm, lowercased_tag, lowercased_tag + tag_len -1);
    append(sm, "\"></a>");
  };

  thumb_id => {
    if(sm->thumbnails_left > 0) {
      long post_id = strtol(sm->a1, (char**)&sm->a2, 10);
      g_array_append_val(sm->posts, post_id);
      sm->thumbnails_left -= 1;
      append(sm, "<a class=\"dtext-link dtext-id-link dtext-post-id-link thumb-placeholder-link\" data-id=\"");
      append_segment_html_escaped(sm, sm->a1, sm->a2 - 1);
      append(sm, "\" href=\"");
      append_url(sm, "/posts/");
      append_segment_uri_escaped(sm, sm->a1, sm->a2 -1);
      append(sm, "\">");
      append(sm, "post #");
      append_segment_html_escaped(sm, sm->a1, sm->a2 - 1);
      append(sm, "</a>");
    } else {
      append_id_link(sm, "post", "post", "/posts/");
    }
  };

  post_id => { append_id_link(sm, "post", "post", "/posts/"); };
  post_changes_for_id => { append_id_link(sm, "post changes", "post-changes-for", "/post_versions?search[post_id]="); };
  post_flag_id => { append_id_link(sm, "flag", "post-flag", "/post_flags/"); };
  note_id => { append_id_link(sm, "note", "note", "/notes/"); };
  forum_post_id => { append_id_link(sm, "forum", "forum-post", "/forum_posts/"); };
  forum_topic_id => { append_id_link(sm, "topic", "forum-topic", "/forum_topics/"); };
  comment_id =>{ append_id_link(sm, "comment", "comment", "/comments/"); };
  pool_id =>{ append_id_link(sm, "pool", "pool", "/pools/"); };
  user_id =>{ append_id_link(sm, "user", "user", "/users/"); };
  artist_id =>{ append_id_link(sm, "artist", "artist", "/artists/"); };
  ban_id =>{ append_id_link(sm, "ban", "ban", "/bans/"); };
  bulk_update_request_id =>{ append_id_link(sm, "BUR", "bulk-update-request", "/bulk_update_requests/"); };
  tag_alias_id =>{ append_id_link(sm, "alias", "tag-alias", "/tag_aliases/"); };
  tag_implication_id =>{ append_id_link(sm, "implication", "tag-implication", "/tag_implications/"); };
  mod_action_id =>{ append_id_link(sm, "mod action", "mod-action", "/mod_actions/"); };
  user_feedback_id =>{ append_id_link(sm, "record", "user-feedback", "/user_feedbacks/"); };
  wiki_page_id =>{ append_id_link(sm, "wiki", "wiki-page", "/wiki_pages/"); };
  set_id =>{ append_id_link(sm, "set", "set", "/post_sets/"); };
  blip_id =>{ append_id_link(sm, "blip", "blip", "/blips/"); };
  ticket_id =>{ append_id_link(sm, "ticket", "ticket", "/tickets/"); };
  takedown_id =>{ append_id_link(sm, "takedown", "takedown", "/takedowns/"); };

  basic_post_search_link => {
    append_post_search_link(sm, sm->a1, sm->a2 - sm->a1, sm->a1, sm->a2 - sm->a1);
  };

  aliased_post_search_link => {
    append_post_search_link(sm, sm->a1, sm->a2 - sm->a1, sm->b1, sm->b2 - sm->b1);
  };

  basic_wiki_link => {
    append_wiki_link(sm, sm->a1, sm->a2 - sm->a1, sm->a1, sm->a2 - sm->a1);
  };

  aliased_wiki_link => {
    append_wiki_link(sm, sm->a1, sm->a2 - sm->a1, sm->b1, sm->b2 - sm->b1);
  };

  basic_textile_link => {
    const char* match_end = sm->b2;
    const char* url_start = sm->b1;
    const char* url_end = find_boundary_c(match_end);

    if (!append_named_url(sm, url_start, url_end, sm->a1, sm->a2)) {
      fbreak;
    }

    if (url_end < match_end) {
      append_segment_html_escaped(sm, url_end + 1, match_end);
    }
  };

  bracketed_textile_link => {
    if (!append_named_url(sm, sm->b1, sm->b2, sm->a1, sm->a2)) {
      fbreak;
    }
  };

  url => {
    const char* match_end = sm->te - 1;
    const char* url_start = sm->ts;
    const char* url_end = find_boundary_c(match_end);

    append_unnamed_url(sm, url_start, url_end);

    if (url_end < match_end) {
      append_segment_html_escaped(sm, url_end + 1, match_end);
    }
  };

  delimited_url => {
    append_unnamed_url(sm, sm->ts + 1, sm->te - 2);
  };

  # probably a tag. examples include @.@ and @_@
  '@' graph '@' => {
    append_segment_html_escaped(sm, sm->ts, sm->te - 1);
  };

  newline list_item => {
    g_debug("inline list");

    if (dstack_check(sm, BLOCK_LI)) {
      g_debug("  rewind li");
      dstack_rewind(sm);
    } else if (dstack_check(sm, BLOCK_P)) {
      g_debug("  rewind p");
      dstack_rewind(sm);
    } else if (sm->header_mode) {
      g_debug("  rewind header");
      dstack_rewind(sm);
    }

    g_debug("  next list");
    fexec sm->ts + 1;
    fnext list;
  };

  '[b]'i  => { dstack_open_inline(sm,  INLINE_B, "<strong>"); };
  '[/b]'i => { dstack_close_inline(sm, INLINE_B, "</strong>"); };
  '[i]'i  => { dstack_open_inline(sm,  INLINE_I, "<em>"); };
  '[/i]'i => { dstack_close_inline(sm, INLINE_I, "</em>"); };
  '[s]'i  => { dstack_open_inline(sm,  INLINE_S, "<s>"); };
  '[/s]'i => { dstack_close_inline(sm, INLINE_S, "</s>"); };
  '[u]'i  => { dstack_open_inline(sm,  INLINE_U, "<u>"); };
  '[/u]'i => { dstack_close_inline(sm, INLINE_U, "</u>"); };
  '[sup]'i  => { dstack_open_inline(sm, INLINE_SUP, "<sup>"); };
  '[/sup]'i => { dstack_close_inline(sm, INLINE_SUP, "</sup>"); };
  '[sub]'i  => { dstack_open_inline(sm, INLINE_SUB, "<sub>"); };
  '[/sub]'i => { dstack_close_inline(sm, INLINE_SUB, "</sub>"); };

  '[tn]'i => {
    dstack_open_inline(sm, INLINE_TN, "<span class=\"tn\">");
  };

  '[/tn]'i => {
    dstack_close_before_block(sm);

    if (dstack_check(sm, INLINE_TN)) {
      dstack_close_inline(sm, INLINE_TN, "</span>");
    } else if (dstack_close_block(sm, BLOCK_TN, "</p>")) {
      fret;
    }
  };

  color_typed => {
    if(!sm->allow_color)
      fret;
    dstack_push(sm, INLINE_COLOR);
    append(sm, "<span class=\"dtext-color-");
    append_segment_uri_escaped(sm, sm->a1, sm->a2-1);
    append(sm, "\">");
  };

  color_open => {
    if(!sm->allow_color)
      fret;
    dstack_push(sm, INLINE_COLOR);
    append(sm, "<span class=\"dtext-color\" style=\"color:");
    if(sm->a1[0] == '#') {
      append(sm, "#");
      append_segment_uri_escaped(sm, sm->a1 + 1, sm->a2-1);
    } else {
      append_segment_uri_escaped(sm, sm->a1, sm->a2-1);
    }
    append(sm, "\">");
  };

  color_close => {
    if(!sm->allow_color)
      fret;
    dstack_close_inline(sm, INLINE_COLOR, "</span>");
  };

  spoilers_open => {
    dstack_open_inline(sm, INLINE_SPOILER, "<span class=\"spoiler\">");
  };

  spoilers_close => {
    g_debug("inline [/spoiler]");
    dstack_close_before_block(sm);

    if (dstack_check(sm, INLINE_SPOILER)) {
      dstack_close_inline(sm, INLINE_SPOILER, "</span>");
    } else if (dstack_close_block(sm, BLOCK_SPOILER, "</div>")) {
      fret;
    }
  };

  '[nodtext]'i => {
    dstack_open_inline(sm, INLINE_NODTEXT, "");
    fcall nodtext;
  };

  # these are block level elements that should kick us out of the inline
  # scanner

  '[table]'i => {
    dstack_close_before_block(sm);
    fexec sm->ts;
    fret;
  };

  '[/table]'i space* => {
    g_debug("inline [/table]");
    dstack_close_before_block(sm);

    if (dstack_check(sm, BLOCK_LI)) {
      dstack_close_list(sm);
    }

    if (dstack_check(sm, BLOCK_TABLE)) {
      dstack_rewind(sm);
      fret;
    } else {
      append_block(sm, "[/table]");
    }
  };

  '[code]'i => {
    dstack_close_before_block(sm);
    fexec sm->ts;
    fret;
  };

  '[/code]'i space* => {
    g_debug("inline [/code]");
    dstack_close_before_block(sm);

    if (dstack_check(sm, BLOCK_LI)) {
      dstack_close_list(sm);
    }

    if (dstack_check(sm, BLOCK_CODE)) {
      dstack_rewind(sm);
      fret;
    } else {
      append_block(sm, "[/code]");
    }
  };

  '[quote]'i => {
    g_debug("inline [quote]");
    dstack_close_before_block(sm);
    fexec sm->ts;
    fret;
  };

  '[/quote]'i space* => {
    g_debug("inline [/quote]");
    dstack_close_before_block(sm);

    if (dstack_check(sm, BLOCK_LI)) {
      dstack_close_list(sm);
    }

    if (dstack_is_open(sm, BLOCK_QUOTE)) {
      dstack_close_until(sm, BLOCK_QUOTE);
      fret;
    } else {
      append_block(sm, "[/quote]");
    }
  };

  '[section]'i => {
    g_debug("inline [section]");
    dstack_rewind(sm);
    fexec(sm->p - 8);
    fret;
  };

  '[section,expanded]'i => {
    g_debug("inline expanded [section]");
    dstack_rewind(sm);
    fexec(sm->p - 17);
    fret;
  };

  '[/section]'i => {
    dstack_close_before_block(sm);

    if (dstack_close_block(sm, BLOCK_SECTION, "</details>")) {
      fret;
    }
  };

  aliased_section => {
    dstack_rewind(sm);
    fexec(sm->p - 9 - (sm->a2 - sm->a1));
    fret;
  };

  aliased_section_expanded => {
    dstack_rewind(sm);
    fexec(sm->p - 18 - (sm->a2 - sm->a1));
    fret;
  };

  '[/th]'i => {
    if (dstack_close_block(sm, BLOCK_TH, "</th>")) {
      fret;
    }
  };

  '[/td]'i => {
    if (dstack_close_block(sm, BLOCK_TD, "</td>")) {
      fret;
    }
  };

  newline{2,} => {
    g_debug("inline newline2");
    g_debug("  return");

    dstack_close_list(sm);

    fexec sm->ts;
    fret;
  };

  newline => {
    g_debug("inline newline");

    if (sm->header_mode) {
      sm->header_mode = false;
      dstack_rewind(sm);
      fret;
    } else {
      append(sm, "<br>");
    }
  };

  '\r' => {
    append_c_html_escaped(sm, ' ');
  };

  any => {
    g_debug("inline char: %c", fc);
    append_c_html_escaped(sm, fc);
  };
*|;

inline_code := |*
  '\\`' => {
    append(sm, "`");
  };

  '`' => {
    append(sm, "</span>");
    fret;
  };

  any => {
    append_c_html_escaped(sm, fc);
  };
*|;

code := |*
  '[/code]'i => {
    if (dstack_check(sm, BLOCK_CODE)) {
      dstack_rewind(sm);
    } else {
      append(sm, "[/code]");
    }
    fret;
  };

  any => {
    append_c_html_escaped(sm, fc);
  };
*|;

nodtext := |*
  '[/nodtext]'i => {
    if (dstack_check2(sm, BLOCK_NODTEXT)) {
      g_debug("block dstack check");
      dstack_pop(sm);
      dstack_pop(sm);
      append_block(sm, "</p>");
      fret;
    } else if (dstack_check(sm, INLINE_NODTEXT)) {
      g_debug("inline dstack check");
      dstack_pop(sm);
      fret;
    } else {
      g_debug("else dstack check");
      append(sm, "[/nodtext]");
    }
  };

  any => {
    append_c_html_escaped(sm, fc);
  };
*|;

table := |*
  '[thead]'i => {
    dstack_open_block(sm, BLOCK_THEAD, "<thead>");
  };

  '[/thead]'i => {
    dstack_close_block(sm, BLOCK_THEAD, "</thead>");
  };

  '[tbody]'i => {
    dstack_open_block(sm, BLOCK_TBODY, "<tbody>");
  };

  '[/tbody]'i => {
    dstack_close_block(sm, BLOCK_TBODY, "</tbody>");
  };

  '[th]'i => {
    dstack_open_block(sm, BLOCK_TH, "<th>");
    fcall inline;
  };

  '[tr]'i => {
    dstack_open_block(sm, BLOCK_TR, "<tr>");
  };

  '[/tr]'i => {
    dstack_close_block(sm, BLOCK_TR, "</tr>");
  };

  '[td]'i => {
    dstack_open_block(sm, BLOCK_TD, "<td>");
    fcall inline;
  };

  '[/table]'i => {
    if (dstack_close_block(sm, BLOCK_TABLE, "</table>")) {
      fret;
    }
  };

  any;
*|;

list := |*
  list_item => {
    int prev_nest = sm->list_nest;
    append_closing_p_if(sm);
    g_debug("list start");
    sm->list_nest = sm->a2 - sm->a1;
    fexec sm->b1;

    if (sm->list_nest > prev_nest) {
      for (int i = prev_nest; i < sm->list_nest; ++i) {
        dstack_open_block(sm, BLOCK_UL, "<ul>");
      }
    } else if (sm->list_nest < prev_nest) {
      for (int i = sm->list_nest; i < prev_nest; ++i) {
        if (dstack_check(sm, BLOCK_UL)) {
          dstack_rewind(sm);
        }
      }
    }

    dstack_open_block(sm, BLOCK_LI, "<li>");

    g_debug("  call inline");

    fcall inline;
  };

  # exit list
  newline{2,} => {
    dstack_close_list(sm);
    fexec sm->ts;
    fret;
  };

  newline;

  any => {
    dstack_rewind(sm);
    fhold;
    fret;
  };
*|;

main := |*
  '\\`' => {
    append(sm, "`");
  };

  '`' => {
    append(sm, "<span class=\"inline-code\">");
    fcall inline_code;
  };

  header_with_id => {
    char header = *sm->a1;
    g_autoptr(GString) id_name = g_string_new_len(sm->b1, sm->b2 - sm->b1);
    id_name = g_string_prepend(id_name, "dtext-");

    if (sm->f_inline) {
      header = '6';
    }

    switch (header) {
      case '1':
        dstack_push(sm, BLOCK_H1);
        append_block(sm, "<h1 id=\"");
        append_block(sm, id_name->str);
        append_block(sm, "\">");
        break;

      case '2':
        dstack_push(sm, BLOCK_H2);
        append_block(sm, "<h2 id=\"");
        append_block(sm, id_name->str);
        append_block(sm, "\">");
        break;

      case '3':
        dstack_push(sm, BLOCK_H3);
        append_block(sm, "<h3 id=\"");
        append_block(sm, id_name->str);
        append_block(sm, "\">");
        break;

      case '4':
        dstack_push(sm, BLOCK_H4);
        append_block(sm, "<h4 id=\"");
        append_block(sm, id_name->str);
        append_block(sm, "\">");
        break;

      case '5':
        dstack_push(sm, BLOCK_H5);
        append_block(sm, "<h5 id=\"");
        append_block(sm, id_name->str);
        append_block(sm, "\">");
        break;

      case '6':
        dstack_push(sm, BLOCK_H6);
        append_block(sm, "<h6 id=\"");
        append_block(sm, id_name->str);
        append_block(sm, "\">");
        break;
    }

    sm->header_mode = true;
    fcall inline;
  };

  header => {
    char header = *sm->a1;

    if (sm->f_inline) {
      header = '6';
    }

    switch (header) {
      case '1':
        dstack_push(sm, BLOCK_H1);
        append_block(sm, "<h1>");
        break;

      case '2':
        dstack_push(sm, BLOCK_H2);
        append_block(sm, "<h2>");
        break;

      case '3':
        dstack_push(sm, BLOCK_H3);
        append_block(sm, "<h3>");
        break;

      case '4':
        dstack_push(sm, BLOCK_H4);
        append_block(sm, "<h4>");
        break;

      case '5':
        dstack_push(sm, BLOCK_H5);
        append_block(sm, "<h5>");
        break;

      case '6':
        dstack_push(sm, BLOCK_H6);
        append_block(sm, "<h6>");
        break;
    }

    sm->header_mode = true;
    fcall inline;
  };

  '[quote]'i space* => {
    dstack_close_before_block(sm);
    dstack_open_block(sm, BLOCK_QUOTE, "<blockquote>");
  };

  spoilers_open space* => {
    dstack_close_before_block(sm);
    dstack_open_block(sm, BLOCK_SPOILER, "<div class=\"spoiler\">");
  };

  spoilers_close => {
    g_debug("block [/spoiler]");
    dstack_close_before_block(sm);
    if (dstack_check(sm, BLOCK_SPOILER)) {
      g_debug("  rewind");
      dstack_rewind(sm);
    }
  };

  '[code]'i space* => {
    dstack_close_before_block(sm);
    dstack_open_block(sm, BLOCK_CODE, "<pre>");
    fcall code;
  };

  '[section]'i space* => {
    dstack_close_before_block(sm);
    dstack_open_block(sm, BLOCK_SECTION, "<details>");
    append(sm, "<summary></summary>");
  };

  '[section,expanded]'i space* => {
    dstack_close_before_block(sm);
    dstack_open_block(sm, BLOCK_SECTION, "<details open>");
    append(sm, "<summary></summary>");
  };

  aliased_section space* => {
    g_debug("block [section=]");
    dstack_open_block(sm, BLOCK_SECTION, "<details>");
    append(sm, "<summary>");
    append_segment_html_escaped(sm, sm->a1, sm->a2 - 1);
    append(sm, "</summary>");
  };

  aliased_section_expanded space* => {
    g_debug("block expanded [section=]");
    dstack_open_block(sm, BLOCK_SECTION, "<details open>");
    append(sm, "<summary>");
    append_segment_html_escaped(sm, sm->a1, sm->a2 - 1);
    append(sm, "</summary>");
  };

  '[nodtext]'i space* => {
    dstack_close_before_block(sm);
    dstack_open_block(sm, BLOCK_NODTEXT, "");
    dstack_open_block(sm, BLOCK_P, "<p>");
    fcall nodtext;
  };

  '[table]'i => {
    dstack_close_before_block(sm);
    dstack_open_block(sm, BLOCK_TABLE, "<table class=\"striped\">");
    fcall table;
  };

  '[tn]'i => {
    dstack_open_block(sm, BLOCK_TN, "<p class=\"tn\">");
    fcall inline;
  };

  list_item => {
    g_debug("block list");
    g_debug("  call list");
    sm->list_nest = 0;
    append_closing_p_if(sm);
    fexec sm->ts;
    fcall list;
  };

  newline{2,} => {
    g_debug("block newline2");

    if (sm->header_mode) {
      sm->header_mode = false;
      dstack_rewind(sm);
    } else if (sm->list_nest) {
      dstack_close_list(sm);
    } else {
      dstack_close_before_block(sm);
    }
  };

  newline => {
    g_debug("block newline");
  };

  any => {
    g_debug("block char: %c", fc);
    fhold;

    if (g_queue_is_empty(sm->dstack) || dstack_check(sm, BLOCK_QUOTE) || dstack_check(sm, BLOCK_SPOILER) || dstack_check(sm, BLOCK_SECTION)) {
      dstack_open_block(sm, BLOCK_P, "<p>");
    }

    fcall inline;
  };
*|;

}%%

%% write data;

static inline void dstack_push(StateMachine * sm, element_t element) {
  g_queue_push_tail(sm->dstack, GINT_TO_POINTER(element));
}

static inline element_t dstack_pop(StateMachine * sm) {
  return GPOINTER_TO_INT(g_queue_pop_tail(sm->dstack));
}

static inline element_t dstack_peek(const StateMachine * sm) {
  return GPOINTER_TO_INT(g_queue_peek_tail(sm->dstack));
}

static inline bool dstack_check(const StateMachine * sm, element_t expected_element) {
  return dstack_peek(sm) == expected_element;
}

static inline bool dstack_check2(const StateMachine * sm, element_t expected_element) {
  if (sm->dstack->length < 2) {
    return false;
  }

  element_t top2 = GPOINTER_TO_INT(g_queue_peek_nth(sm->dstack, sm->dstack->length - 2));
  return top2 == expected_element;
}

// Return true if the given tag is currently open.
static inline bool dstack_is_open(const StateMachine * sm, element_t element) {
  return g_queue_index(sm->dstack, GINT_TO_POINTER(element)) != -1;
}

static inline void append(StateMachine * sm, const char * s) {
  sm->output = g_string_append(sm->output, s);
}

static inline void append_c_html_escaped(StateMachine * sm, char s) {
  switch (s) {
    case '<':
      sm->output = g_string_append(sm->output, "&lt;");
      break;

    case '>':
      sm->output = g_string_append(sm->output, "&gt;");
      break;

    case '&':
      sm->output = g_string_append(sm->output, "&amp;");
      break;

    case '"':
      sm->output = g_string_append(sm->output, "&quot;");
      break;

    default:
      sm->output = g_string_append_c(sm->output, s);
      break;
  }
}

static inline void append_segment(StateMachine * sm, const char * a, const char * b) {
  sm->output = g_string_append_len(sm->output, a, b - a + 1);
}

static inline void append_segment_uri_escaped(StateMachine * sm, const char * a, const char * b) {
  g_autofree char * segment1 = NULL;
  g_autofree char * segment2 = NULL;
  g_autoptr(GString) segment_string = g_string_new_len(a, b - a + 1);

  segment1 = g_uri_escape_string(segment_string->str, NULL, TRUE);
  segment2 = g_markup_escape_text(segment1, -1);
  sm->output = g_string_append(sm->output, segment2);
}

static inline void append_segment_uri_possible_fragment_escaped(StateMachine * sm, const char * a, const char * b) {
  g_autofree char * segment1 = NULL;
  g_autofree char * segment2 = NULL;
  g_autoptr(GString) segment_string = g_string_new_len(a, b - a + 1);

  segment1 = g_uri_escape_string(segment_string->str, "#", TRUE);
  segment2 = g_markup_escape_text(segment1, -1);
  sm->output = g_string_append(sm->output, segment2);
}

static inline void append_segment_html_escaped(StateMachine * sm, const char * a, const char * b) {
  g_autofree gchar * segment = g_markup_escape_text(a, b - a + 1);
  sm->output = g_string_append(sm->output, segment);
}

static inline void append_url(StateMachine * sm, const char* url) {
  if ((url[0] == '/' || url[0] == '#') && sm->base_url) {
    append(sm, sm->base_url);
  }

  append(sm, url);
}

static inline void append_id_link(StateMachine * sm, const char * title, const char * id_name, const char * url) {
  append(sm, "<a class=\"dtext-link dtext-id-link dtext-");
  append(sm, id_name);
  append(sm, "-id-link\" href=\"");
  append_url(sm, url);
  append_segment_uri_escaped(sm, sm->a1, sm->a2 - 1);
  append(sm, "\">");
  append(sm, title);
  append(sm, " #");
  append_segment_html_escaped(sm, sm->a1, sm->a2 - 1);
  append(sm, "</a>");
}

static inline void append_unnamed_url(StateMachine * sm, const char * url_start, const char * url_end) {
  append(sm, "<a rel=\"nofollow\" class=\"dtext-link\" href=\"");
  append_segment_html_escaped(sm, url_start, url_end);
  append(sm, "\">");
  append_segment_html_escaped(sm, url_start, url_end);
  append(sm, "</a>");
}

static inline bool append_named_url(StateMachine * sm, const char * url_start, const char * url_end, const char * title_start, const char * title_end) {
  g_autoptr(GString) parsed_title = parse_basic_inline(title_start, title_end - title_start);

  if (!parsed_title) {
    return false;
  }

  if (url_start[0] == '/' || url_start[0] == '#') {
    append(sm, "<a rel=\"nofollow\" class=\"dtext-link\" href=\"");
    if (sm->base_url) {
      append(sm, sm->base_url);
    }
  } else {
    append(sm, "<a rel=\"nofollow\" class=\"dtext-link dtext-external-link\" href=\"");
  }

  append_segment_html_escaped(sm, url_start, url_end);
  append(sm, "\">");
  append_segment(sm, parsed_title->str, parsed_title->str + parsed_title->len - 1);
  append(sm, "</a>");

  return true;
}

static inline void append_wiki_link(StateMachine * sm, const char * tag, const size_t tag_len, const char * title, const size_t title_len) {
  g_autofree gchar* lowercased_tag = g_utf8_strdown(tag, tag_len);
  g_autoptr(GString) normalized_tag = g_string_new(g_strdelimit(lowercased_tag, " ", '_'));

  if (tag[0] == '#') {
    append(sm, "<a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"#");
    append_segment_uri_escaped(sm, lowercased_tag+1, lowercased_tag + tag_len - 1);
    append(sm, "\">");
  } else {
    append(sm, "<a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"");
    append_url(sm, "/wiki_pages/show_or_new?title=");
    append_segment_uri_possible_fragment_escaped(sm, normalized_tag->str, normalized_tag->str + normalized_tag->len - 1);
    append(sm, "\">");
  }
  append_segment_html_escaped(sm, title, title + title_len - 1);
  append(sm, "</a>");
}

static inline void append_post_search_link(StateMachine * sm, const char * tag, const size_t tag_len, const char * title, const size_t title_len) {
  g_autofree gchar* lowercased_tag = g_utf8_strdown(tag, tag_len);
  g_autoptr(GString) normalized_tag = g_string_new(lowercased_tag);

  append(sm, "<a rel=\"nofollow\" class=\"dtext-link dtext-post-search-link\" href=\"");
  append_url(sm, "/posts?tags=");
  append_segment_uri_escaped(sm, normalized_tag->str, normalized_tag->str + normalized_tag->len - 1);
  append(sm, "\">");
  append_segment_html_escaped(sm, title, title + title_len - 1);
  append(sm, "</a>");
}

static inline void append_block_segment(StateMachine * sm, const char * a, const char * b) {
  if (sm->f_inline) {
    // sm->output = g_string_append_c(sm->output, ' ');
  } else {
    sm->output = g_string_append_len(sm->output, a, b - a + 1);
  }
}

static inline void append_block(StateMachine * sm, const char * s) {
  append_block_segment(sm, s, s + strlen(s) - 1);
}

static void append_closing_p(StateMachine * sm) {
  size_t i = sm->output->len;

  if (i > 4 && !strncmp(sm->output->str + i - 4, "<br>", 4)) {
    sm->output = g_string_truncate(sm->output, sm->output->len - 4);
  }

  if (i > 3 && !strncmp(sm->output->str + i - 3, "<p>", 3)) {
    sm->output = g_string_truncate(sm->output, sm->output->len - 3);
    return;
  }

  append_block(sm, "</p>");
}

static void append_closing_p_if(StateMachine * sm) {
  if (!dstack_check(sm, BLOCK_P)) {
    return;
  }

  dstack_pop(sm);
  append_closing_p(sm);
}

static void dstack_open_inline(StateMachine * sm, element_t type, const char * html) {
  g_debug("push inline element [%d]: %s", type, html);

  dstack_push(sm, type);
  append(sm, html);
}

static void dstack_open_block(StateMachine * sm, element_t type, const char * html) {
  g_debug("push block element [%d]: %s", type, html);

  dstack_push(sm, type);
  append_block(sm, html);
}

static void dstack_close_inline(StateMachine * sm, element_t type, const char * close_html) {
  if (dstack_check(sm, type)) {
    g_debug("pop inline element [%d]: %s", type, close_html);

    dstack_pop(sm);
    append(sm, close_html);
  } else {
    g_debug("ignored out-of-order closing inline tag [%d]", type);

    append_segment(sm, sm->ts, sm->te - 1);
  }
}

static bool dstack_close_block(StateMachine * sm, element_t type, const char * close_html) {
  if (dstack_check(sm, type)) {
    g_debug("pop block element [%d]: %s", type, close_html);

    dstack_pop(sm);
    append_block(sm, close_html);
    return true;
  } else {
    g_debug("ignored out-of-order closing block tag [%d]", type);

    append_block_segment(sm, sm->ts, sm->te - 1);
    return false;
  }
}

// Close the last open tag.
static void dstack_rewind(StateMachine * sm) {
  element_t element = dstack_pop(sm);

  switch(element) {
    case BLOCK_P: append_closing_p(sm); break;
    case INLINE_SPOILER: append(sm, "</span>"); break;
    case BLOCK_SPOILER: append_block(sm, "</div>"); break;
    case BLOCK_QUOTE: append_block(sm, "</blockquote>"); break;
    case BLOCK_SECTION: append_block(sm, "</details>"); break;
    case BLOCK_NODTEXT: append_closing_p(sm); break;
    case BLOCK_CODE: append_block(sm, "</pre>"); break;
    case BLOCK_TD: append_block(sm, "</td>"); break;
    case BLOCK_TH: append_block(sm, "</th>"); break;

    case INLINE_NODTEXT: break;
    case INLINE_B: append(sm, "</strong>"); break;
    case INLINE_I: append(sm, "</em>"); break;
    case INLINE_U: append(sm, "</u>"); break;
    case INLINE_S: append(sm, "</s>"); break;
    case INLINE_SUB: append(sm, "</sub>"); break;
    case INLINE_SUP: append(sm, "</sup>"); break;
    case INLINE_COLOR: append(sm, "</span>"); break;
    case INLINE_TN: append(sm, "</span>"); break;

    case BLOCK_TN: append_closing_p(sm); break;
    case BLOCK_TABLE: append_block(sm, "</table>"); break;
    case BLOCK_THEAD: append_block(sm, "</thead>"); break;
    case BLOCK_TBODY: append_block(sm, "</tbody>"); break;
    case BLOCK_TR: append_block(sm, "</tr>"); break;
    case BLOCK_UL: append_block(sm, "</ul>"); break;
    case BLOCK_LI: append_block(sm, "</li>"); break;
    case BLOCK_H6: append_block(sm, "</h6>"); break;
    case BLOCK_H5: append_block(sm, "</h5>"); break;
    case BLOCK_H4: append_block(sm, "</h4>"); break;
    case BLOCK_H3: append_block(sm, "</h3>"); break;
    case BLOCK_H2: append_block(sm, "</h2>"); break;
    case BLOCK_H1: append_block(sm, "</h1>"); break;

    case QUEUE_EMPTY: break;
  }
}

// Close the last open paragraph or list, if there is one.
static void dstack_close_before_block(StateMachine * sm) {
  while (dstack_check(sm, BLOCK_P) || dstack_check(sm, BLOCK_LI) || dstack_check(sm, BLOCK_UL)) {
    dstack_rewind(sm);
  }
}

// Close all remaining open tags.
static void dstack_close_all(StateMachine * sm) {
  while (!g_queue_is_empty(sm->dstack)) {
    dstack_rewind(sm);
  }
}

// Close all open tags up to and including the given tag.
static void dstack_close_until(StateMachine * sm, element_t element) {
  while (!g_queue_is_empty(sm->dstack) && !dstack_check(sm, element)) {
    dstack_rewind(sm);
  }

  dstack_rewind(sm);
}

static void dstack_close_list(StateMachine * sm) {
  while (dstack_check(sm, BLOCK_LI) || dstack_check(sm, BLOCK_UL)) {
    dstack_rewind(sm);
  }

  sm->list_nest = 0;
}

// Returns the preceding non-boundary character if `c` is a boundary character.
// Otherwise, returns `c` if `c` is not a boundary character. Boundary characters
// are trailing punctuation characters that should not be part of the matched text.
static inline const char* find_boundary_c(const char* c) {
  gunichar ch = g_utf8_get_char(g_utf8_prev_char(c + 1));
  int offset = 0;

  // Close punctuation: http://www.fileformat.info/info/unicode/category/Pe/list.htm
  // U+3000 - U+303F: http://www.fileformat.info/info/unicode/block/cjk_symbols_and_punctuation/list.htm
  if (g_unichar_type(ch) == G_UNICODE_CLOSE_PUNCTUATION || (ch >= 0x3000 && ch <= 0x303F)) {
    offset = g_unichar_to_utf8(ch, NULL);
  }

  switch (*c) {
    case ':':
    case ';':
    case '.':
    case ',':
    case '!':
    case '?':
    case ')':
    case ']':
    case '<':
    case '>':
      offset = 1;
  }

  return c - offset;
}

StateMachine* init_machine(const char * src, size_t len, bool f_inline, bool f_color, long f_max_thumbs) {
  StateMachine* sm = (StateMachine *)g_malloc0(sizeof(StateMachine));

  size_t output_length = len;
  if (output_length < (INT16_MAX / 2)) {
    output_length *= 2;
  }

  sm->p = src;
  sm->pb = sm->p;
  sm->pe = sm->p + len;
  sm->eof = sm->pe;
  sm->ts = NULL;
  sm->te = NULL;
  sm->cs = dtext_start;
  sm->act = 0;
  sm->top = 0;
  sm->output = g_string_sized_new(output_length);
  sm->a1 = NULL;
  sm->a2 = NULL;
  sm->b1 = NULL;
  sm->b2 = NULL;
  sm->f_inline = f_inline;
  sm->allow_color = f_color;
  sm->thumbnails_left = f_max_thumbs < 0 ? 5000 : f_max_thumbs; // Cap for sanity even if "unlimited"
  sm->posts = g_array_sized_new(FALSE, TRUE, sizeof(long), 10);
  sm->stack = g_array_sized_new(FALSE, TRUE, sizeof(int), 16);
  sm->dstack = g_queue_new();
  sm->error = NULL;
  sm->list_nest = 0;
  sm->header_mode = false;

  return sm;
}

void free_machine(StateMachine * sm) {
  g_string_free(sm->output, TRUE);
  g_array_unref(sm->stack);
  g_array_unref(sm->posts);
  g_queue_free(sm->dstack);
  g_clear_error(&sm->error);
  g_free(sm);
}

GQuark dtext_parse_error_quark() {
  return g_quark_from_static_string("dtext-parse-error-quark");
}

GString* parse_basic_inline(const char* dtext, const ssize_t length) {
    GString* output = NULL;
    StateMachine* sm = init_machine(dtext, length, true, false, 0);
    sm->cs = dtext_en_basic_inline;

    if (parse_helper(sm)) {
      output = g_string_new(sm->output->str);
    } else {
      g_debug("parse_basic_inline failed");
    }

    free_machine(sm);
    return output;
}

gboolean parse_helper(StateMachine* sm) {
  const gchar* end = NULL;

  g_debug("start\n");

  if (!g_utf8_validate(sm->pb, sm->pe - sm->pb, &end)) {
    g_set_error(&sm->error, DTEXT_PARSE_ERROR, DTEXT_PARSE_ERROR_INVALID_UTF8, "invalid utf8 starting at byte %td", end - sm->pb + 1);
    return FALSE;
  }

  %% write init nocs;
  %% write exec;

  dstack_close_all(sm);

  return sm->error == NULL;
}
