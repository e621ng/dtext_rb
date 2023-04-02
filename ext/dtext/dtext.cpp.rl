#include "dtext.h"

#include <string.h>
#include <algorithm>
#include <tuple>

#ifdef DEBUG
#undef g_debug
#define STRINGIFY(x) XSTRINGIFY(x)
#define XSTRINGIFY(x) #x
#define g_debug(fmt, ...) fprintf(stderr, "\x1B[1;32mDEBUG\x1B[0m %-28.28s %-24.24s " fmt "\n", __FILE__ ":" STRINGIFY(__LINE__), __func__, ##__VA_ARGS__)
#else
#undef g_debug
#define g_debug(...)
#endif

static const size_t MAX_STACK_DEPTH = 512;

// Characters that mark the end of a link.
//
// http://www.fileformat.info/info/unicode/category/Pe/list.htm
// http://www.fileformat.info/info/unicode/block/cjk_symbols_and_punctuation/list.htm
static char32_t boundary_characters[] = {
  0x0021, // '!' U+0021 EXCLAMATION MARK
  0x0029, // ')' U+0029 RIGHT PARENTHESIS
  0x002C, // ',' U+002C COMMA
  0x002E, // '.' U+002E FULL STOP
  0x003A, // ':' U+003A COLON
  0x003B, // ';' U+003B SEMICOLON
  0x003C, // '<' U+003C LESS-THAN SIGN
  0x003E, // '>' U+003E GREATER-THAN SIGN
  0x003F, // '?' U+003F QUESTION MARK
  0x005D, // ']' U+005D RIGHT SQUARE BRACKET
  0x007D, // '}' U+007D RIGHT CURLY BRACKET
  0x276D, // '❭' U+276D MEDIUM RIGHT-POINTING ANGLE BRACKET ORNAMENT
  0x3000, // '　' U+3000 IDEOGRAPHIC SPACE (U+3000)
  0x3001, // '、' U+3001 IDEOGRAPHIC COMMA (U+3001)
  0x3002, // '。' U+3002 IDEOGRAPHIC FULL STOP (U+3002)
  0x3008, // '〈' U+3008 LEFT ANGLE BRACKET (U+3008)
  0x3009, // '〉' U+3009 RIGHT ANGLE BRACKET (U+3009)
  0x300A, // '《' U+300A LEFT DOUBLE ANGLE BRACKET (U+300A)
  0x300B, // '》' U+300B RIGHT DOUBLE ANGLE BRACKET (U+300B)
  0x300C, // '「' U+300C LEFT CORNER BRACKET (U+300C)
  0x300D, // '」' U+300D RIGHT CORNER BRACKET (U+300D)
  0x300E, // '『' U+300E LEFT WHITE CORNER BRACKET (U+300E)
  0x300F, // '』' U+300F RIGHT WHITE CORNER BRACKET (U+300F)
  0x3010, // '【' U+3010 LEFT BLACK LENTICULAR BRACKET (U+3010)
  0x3011, // '】' U+3011 RIGHT BLACK LENTICULAR BRACKET (U+3011)
  0x3014, // '〔' U+3014 LEFT TORTOISE SHELL BRACKET (U+3014)
  0x3015, // '〕' U+3015 RIGHT TORTOISE SHELL BRACKET (U+3015)
  0x3016, // '〖' U+3016 LEFT WHITE LENTICULAR BRACKET (U+3016)
  0x3017, // '〗' U+3017 RIGHT WHITE LENTICULAR BRACKET (U+3017)
  0x3018, // '〘' U+3018 LEFT WHITE TORTOISE SHELL BRACKET (U+3018)
  0x3019, // '〙' U+3019 RIGHT WHITE TORTOISE SHELL BRACKET (U+3019)
  0x301A, // '〚' U+301A LEFT WHITE SQUARE BRACKET (U+301A)
  0x301B, // '〛' U+301B RIGHT WHITE SQUARE BRACKET (U+301B)
  0x301C, // '〜' U+301C WAVE DASH (U+301C)
  0xFF09, // '）' U+FF09 FULLWIDTH RIGHT PARENTHESIS
  0xFF3D, // '］' U+FF3D FULLWIDTH RIGHT SQUARE BRACKET
  0xFF5D, // '｝' U+FF5D FULLWIDTH RIGHT CURLY BRACKET
  0xFF60, // '｠' U+FF60 FULLWIDTH RIGHT WHITE PARENTHESIS
  0xFF63, // '｣' U+FF63 HALFWIDTH RIGHT CORNER BRACKET
};

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
variable stack (sm->stack.data());

prepush {
  size_t len = sm->stack.size();

  // Should never happen.
  if (len > MAX_STACK_DEPTH) {
    throw DTextError("too many nested elements");
  }

  if (sm->top >= len) {
    g_debug("growing sm->stack %zi\n", len + 16);
    sm->stack.resize(len + 16, 0);
  }
}

action mark_a1 { sm->a1 = sm->p; }
action mark_a2 { sm->a2 = sm->p; }
action mark_b1 { sm->b1 = sm->p; }
action mark_b2 { sm->b2 = sm->p; }

action in_quote { dstack_is_open(sm, BLOCK_QUOTE) }
action in_section { dstack_is_open(sm, BLOCK_SECTION) }

newline = '\r\n' | '\n';

nonnewline = any - (newline | '\r');
nonquote = ^'"';
nonbracket = ^']';
nonpipe = ^'|';
nonpipebracket = nonpipe & nonbracket;
noncurly = ^'}';
nonpipecurly = nonpipe & noncurly;

url = 'http'i 's'i? '://' ^space+;
delimited_url = '<' url :>> '>';
internal_url = [/#] ^space+;
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

section_open = '[section]'i;
section_open_expanded = '[section,expanded]'i;
section_close = '[/section'i (']' when in_section);
section_open_aliased = '[section='i (nonbracket+ >mark_a1 %mark_a2) ']';
section_open_aliased_expanded = '[section,expanded='i (nonbracket+ >mark_a1 %mark_a2) ']';

quote_open = '[quote]'i;
quote_close = '[/quote'i (']' when in_quote);

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
  any => { append_html_escaped(sm, fc); };
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
    std::string lowercased_tag = std::string(sm->a1, sm->a2-sm->a1);
    std::transform(lowercased_tag.begin(), lowercased_tag.end(), lowercased_tag.begin(), [](unsigned char c) { return std::tolower(c); });
    append_segment_uri_escaped(sm, lowercased_tag.c_str(), lowercased_tag.c_str() + lowercased_tag.size() - 1);
    append(sm, "\"></a>");
  };

  thumb_id => {
    if(sm->posts.size() < sm->options.max_thumbs) {
      long post_id = strtol(sm->a1, (char**)&sm->a2, 10);
      sm->posts.push_back(post_id);
      append(sm, "<a class=\"dtext-link dtext-id-link dtext-post-id-link thumb-placeholder-link\" data-id=\"");
      append_html_escaped(sm, sm->a1, sm->a2 - 1);
      append(sm, "\" href=\"");
      append_url(sm, "/posts/");
      append_segment_uri_escaped(sm, sm->a1, sm->a2 -1);
      append(sm, "\">");
      append(sm, "post #");
      append_html_escaped(sm, sm->a1, sm->a2 - 1);
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

    append_named_url(sm, url_start, url_end, sm->a1, sm->a2);

    if (url_end < match_end) {
      append_html_escaped(sm, url_end + 1, match_end);
    }
  };

  bracketed_textile_link => {
    append_named_url(sm, sm->b1, sm->b2, sm->a1, sm->a2);
  };

  url => {
    const char* match_end = sm->te - 1;
    const char* url_start = sm->ts;
    const char* url_end = find_boundary_c(match_end);

    append_unnamed_url(sm, url_start, url_end);

    if (url_end < match_end) {
      append_html_escaped(sm, url_end + 1, match_end);
    }
  };

  delimited_url => {
    append_unnamed_url(sm, sm->ts + 1, sm->te - 2);
  };

  newline list_item => {
    g_debug("inline list");
    fexec sm->ts + 1;
    fret;
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

  color_typed => {
    if(!sm->options.allow_color)
      fret;
    dstack_push(sm, INLINE_COLOR);
    append(sm, "<span class=\"dtext-color-");
    append_segment_uri_escaped(sm, sm->a1, sm->a2-1);
    append(sm, "\">");
  };

  color_open => {
    if(!sm->options.allow_color)
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
    if(!sm->options.allow_color)
      fret;
    dstack_close_inline(sm, INLINE_COLOR, "</span>");
  };

  spoilers_open => {
    dstack_open_inline(sm, INLINE_SPOILER, "<span class=\"spoiler\">");
  };

  newline* spoilers_close => {
    g_debug("inline [/spoiler]");
    dstack_close_before_block(sm);

    if (dstack_check(sm, INLINE_SPOILER)) {
      dstack_close_inline(sm, INLINE_SPOILER, "</span>");
    } else if (dstack_close_block(sm, BLOCK_SPOILER, "</div>")) {
      fret;
    }
  };

  # these are block level elements that should kick us out of the inline
  # scanner

  newline (header | header_with_id) => {
    dstack_close_leaf_blocks(sm);
    fexec sm->ts;
    fret;
  };

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

  quote_open => {
    g_debug("inline [quote]");
    dstack_close_leaf_blocks(sm);
    fexec sm->ts;
    fret;
  };

  newline? quote_close ws* => {
    g_debug("inline [/quote]");
    dstack_close_until(sm, BLOCK_QUOTE);
    fret;
  };

  (section_open | section_open_expanded | section_open_aliased | section_open_aliased_expanded) => {
    g_debug("inline [section]");
    dstack_close_leaf_blocks(sm);
    fexec sm->ts;
    fret;
  };

  newline? section_close ws* => {
    g_debug("inline [/expand]");
    dstack_close_until(sm, BLOCK_SECTION);
    fret;
  };

  '[/th]'i => {
    if (dstack_close_block(sm, BLOCK_TH, "</th>")) {
      fret;
    }
  };

  newline* '[/td]'i => {
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
    } else if (dstack_is_open(sm, BLOCK_UL)) {
      dstack_close_list(sm);
      fret;
    } else {
      append(sm, "<br>");
    }
  };

  '\r' => {
    append(sm, ' ');
  };

  any => {
    g_debug("inline char: %c", fc);
    append_html_escaped(sm, fc);
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
    append_html_escaped(sm, fc);
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
    append_html_escaped(sm, fc);
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
    std::string id_name = "dtext-" + std::string(sm->b1, sm->b2 - sm->b1);

    if (sm->options.f_inline) {
      header = '6';
    }

    switch (header) {
      case '1':
        dstack_push(sm, BLOCK_H1);
        append_block(sm, "<h1 id=\"");
        append_block(sm, id_name);
        append_block(sm, "\">");
        break;

      case '2':
        dstack_push(sm, BLOCK_H2);
        append_block(sm, "<h2 id=\"");
        append_block(sm, id_name);
        append_block(sm, "\">");
        break;

      case '3':
        dstack_push(sm, BLOCK_H3);
        append_block(sm, "<h3 id=\"");
        append_block(sm, id_name);
        append_block(sm, "\">");
        break;

      case '4':
        dstack_push(sm, BLOCK_H4);
        append_block(sm, "<h4 id=\"");
        append_block(sm, id_name);
        append_block(sm, "\">");
        break;

      case '5':
        dstack_push(sm, BLOCK_H5);
        append_block(sm, "<h5 id=\"");
        append_block(sm, id_name);
        append_block(sm, "\">");
        break;

      case '6':
        dstack_push(sm, BLOCK_H6);
        append_block(sm, "<h6 id=\"");
        append_block(sm, id_name);
        append_block(sm, "\">");
        break;
    }

    sm->header_mode = true;
    fcall inline;
  };

  header => {
    char header = *sm->a1;

    if (sm->options.f_inline) {
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

  quote_open space* => {
    dstack_close_leaf_blocks(sm);
    dstack_open_block(sm, BLOCK_QUOTE, "<blockquote>");
  };

  spoilers_open space* => {
    dstack_close_leaf_blocks(sm);
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
    dstack_close_leaf_blocks(sm);
    dstack_open_block(sm, BLOCK_CODE, "<pre>");
    fcall code;
  };

  section_open space* => {
    dstack_close_leaf_blocks(sm);
    dstack_open_block(sm, BLOCK_SECTION, "<details>");
    append(sm, "<summary></summary>");
  };

  section_open_expanded space* => {
    dstack_close_leaf_blocks(sm);
    dstack_open_block(sm, BLOCK_SECTION, "<details open>");
    append(sm, "<summary></summary>");
  };

  section_open_aliased space* => {
    g_debug("block [section=]");
    dstack_close_leaf_blocks(sm);
    dstack_open_block(sm, BLOCK_SECTION, "<details>");
    append(sm, "<summary>");
    append_html_escaped(sm, sm->a1, sm->a2 - 1);
    append(sm, "</summary>");
  };

  section_open_aliased_expanded space* => {
    g_debug("block expanded [section=]");
    dstack_close_leaf_blocks(sm);
    dstack_open_block(sm, BLOCK_SECTION, "<details open>");
    append(sm, "<summary>");
    append_html_escaped(sm, sm->a1, sm->a2 - 1);
    append(sm, "</summary>");
  };

  '[table]'i => {
    dstack_close_leaf_blocks(sm);
    dstack_open_block(sm, BLOCK_TABLE, "<table class=\"striped\">");
    fcall table;
  };

  list_item => {
    g_debug("block list");
    dstack_open_list(sm, sm->a2 - sm->a1);
    fexec sm->b1;
    fcall inline;
  };

  newline{2,} => {
    g_debug("block newline2");

    if (sm->header_mode) {
      sm->header_mode = false;
      dstack_rewind(sm);
    } else if (dstack_is_open(sm, BLOCK_UL)) {
      dstack_close_until(sm, BLOCK_UL);
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

    if (sm->dstack.empty() || dstack_check(sm, BLOCK_QUOTE) || dstack_check(sm, BLOCK_SPOILER) || dstack_check(sm, BLOCK_SECTION)) {
      dstack_open_block(sm, BLOCK_P, "<p>");
    }

    fcall inline;
  };
*|;

}%%

%% write data;

static inline void dstack_push(StateMachine * sm, element_t element) {
  sm->dstack.push_back(element);
}

static inline element_t dstack_pop(StateMachine * sm) {
  if (sm->dstack.empty()) {
    g_debug("dstack pop empty stack");
    return DSTACK_EMPTY;
  } else {
    auto element = sm->dstack.back();
    sm->dstack.pop_back();
    return element;
  }
}

static inline element_t dstack_peek(const StateMachine * sm) {
  return sm->dstack.empty() ? DSTACK_EMPTY : sm->dstack.back();
}

static inline bool dstack_check(const StateMachine * sm, element_t expected_element) {
  return dstack_peek(sm) == expected_element;
}

// Return true if the given tag is currently open.
static inline bool dstack_is_open(const StateMachine * sm, element_t element) {
  return std::find(sm->dstack.begin(), sm->dstack.end(), element) != sm->dstack.end();
}

static inline int dstack_count(const StateMachine * sm, element_t element) {
  return std::count(sm->dstack.begin(), sm->dstack.end(), element);
}

static inline void append(StateMachine * sm, const auto c) {
  sm->output += c;
}

static inline void append(StateMachine * sm, const char * a, const char * b) {
  append(sm, std::string_view(a, b - a));
}

static inline void append_html_escaped(StateMachine * sm, char s) {
  switch (s) {
    case '<': append(sm, "&lt;"); break;
    case '>': append(sm, "&gt;"); break;
    case '&': append(sm, "&amp;"); break;
    case '"': append(sm, "&quot;"); break;
    default:  append(sm, s);
  }
}

static inline void append_html_escaped(StateMachine * sm, const char * a, const char * b) {
  const std::string_view input(a, b - a + 1);

  for (const unsigned char c : input) {
    append_html_escaped(sm, c);
  }
}

static inline void append_segment_uri_escaped(StateMachine * sm, const char * a, const char * b, const char whitelist = '-') {
  static const char hex[] = "0123456789ABCDEF";
  const std::string_view input(a, b - a + 1);

  for (const unsigned char c : input) {
    if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~' || c == whitelist) {
      append(sm, c);
    } else {
      append(sm, '%');
      append(sm, hex[c >> 4]);
      append(sm, hex[c & 0x0F]);
    }
  }
}

static inline void append_url(StateMachine * sm, const char* url) {
  if ((url[0] == '/' || url[0] == '#') && !sm->options.base_url.empty()) {
    append(sm, sm->options.base_url);
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
  append_html_escaped(sm, sm->a1, sm->a2 - 1);
  append(sm, "</a>");
}

static inline void append_unnamed_url(StateMachine * sm, const char * url_start, const char * url_end) {
  append(sm, "<a rel=\"nofollow\" class=\"dtext-link\" href=\"");
  append_html_escaped(sm, url_start, url_end);
  append(sm, "\">");
  append_html_escaped(sm, url_start, url_end);
  append(sm, "</a>");
}

static inline void append_named_url(StateMachine * sm, const char * url_start, const char * url_end, const char * title_start, const char * title_end) {
  auto parsed_title = sm->parse_basic_inline(title_start, title_end - title_start);

  if (url_start[0] == '/' || url_start[0] == '#') {
    append(sm, "<a rel=\"nofollow\" class=\"dtext-link\" href=\"");
    if (!sm->options.base_url.empty()) {
      append(sm, sm->options.base_url);
    }
  } else {
    append(sm, "<a rel=\"nofollow\" class=\"dtext-link dtext-external-link\" href=\"");
  }

  append_html_escaped(sm, url_start, url_end);
  append(sm, "\">");
  append(sm, parsed_title);
  append(sm, "</a>");
}

static inline void append_wiki_link(StateMachine * sm, const char * tag_segment, const size_t tag_len, const char * title_segment, const size_t title_len) {
  std::string normalized_tag = std::string(tag_segment, tag_len);
  std::transform(normalized_tag.begin(), normalized_tag.end(), normalized_tag.begin(), [](unsigned char c) { return c == ' ' ? '_' : std::tolower(c); });

  // FIXME: Take the anchor as an argument here
  if (tag_segment[0] == '#') {
    append(sm, "<a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"#");
    append_segment_uri_escaped(sm, normalized_tag.c_str() + 1, normalized_tag.c_str() + normalized_tag.size() - 1);
    append(sm, "\">");
  } else {
    append(sm, "<a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"");
    append_url(sm, "/wiki_pages/show_or_new?title=");
    append_segment_uri_escaped(sm, normalized_tag.c_str(), normalized_tag.c_str() + normalized_tag.size() - 1, '#');
    append(sm, "\">");
  }
  append_html_escaped(sm, title_segment, title_segment + title_len - 1);
  append(sm, "</a>");
}

static inline void append_post_search_link(StateMachine * sm, const char * tag_segment, const size_t tag_len, const char * title_segment, const size_t title_len) {
  std::string normalized_tag = std::string(tag_segment, tag_len);
  std::transform(normalized_tag.begin(), normalized_tag.end(), normalized_tag.begin(), [](unsigned char c) { return std::tolower(c); });

  append(sm, "<a rel=\"nofollow\" class=\"dtext-link dtext-post-search-link\" href=\"");
  append_url(sm, "/posts?tags=");
  append_segment_uri_escaped(sm, normalized_tag.c_str(), normalized_tag.c_str() + normalized_tag.size() - 1);
  append(sm, "\">");
  append_html_escaped(sm, title_segment, title_segment + title_len - 1);
  append(sm, "</a>");
}

static inline void append_block(StateMachine * sm, const char * a, const char * b) {
  if (!sm->options.f_inline) {
    append(sm, a, b);
  }
}

static inline void append_block(StateMachine * sm, const auto s) {
  if (!sm->options.f_inline) {
    append(sm, s);
  }
}

static void append_closing_p(StateMachine * sm) {
  if (sm->output.size() > 4 && sm->output.ends_with("<br>")) {
    sm->output.resize(sm->output.size() - 4);
  }

  if (sm->output.size() > 3 && sm->output.ends_with("<p>")) {
    sm->output.resize(sm->output.size() - 3);
    return;
  }

  append_block(sm, "</p>");
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

    append(sm, sm->ts, sm->te);
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

    append_block(sm, sm->ts, sm->te);
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
    case BLOCK_CODE: append_block(sm, "</pre>"); break;
    case BLOCK_TD: append_block(sm, "</td>"); break;
    case BLOCK_TH: append_block(sm, "</th>"); break;

    case INLINE_B: append(sm, "</strong>"); break;
    case INLINE_I: append(sm, "</em>"); break;
    case INLINE_U: append(sm, "</u>"); break;
    case INLINE_S: append(sm, "</s>"); break;
    case INLINE_SUB: append(sm, "</sub>"); break;
    case INLINE_SUP: append(sm, "</sup>"); break;
    case INLINE_COLOR: append(sm, "</span>"); break;

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

    case DSTACK_EMPTY: break;
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
  while (!sm->dstack.empty()) {
    dstack_rewind(sm);
  }
}

// container blocks: [quote], [spoiler], [section]
// leaf blocks: [code], [table], [td]?, [th]?, <h1>, <p>, <li>, <ul>
static void dstack_close_leaf_blocks(StateMachine * sm) {
  g_debug("dstack close leaf blocks");

  while (!sm->dstack.empty() && !dstack_check(sm, BLOCK_QUOTE) && !dstack_check(sm, BLOCK_SPOILER) && !dstack_check(sm, BLOCK_SECTION)) {
    dstack_rewind(sm);
  }

  sm->header_mode = false;
}

// Close all open tags up to and including the given tag.
static void dstack_close_until(StateMachine * sm, element_t element) {
  while (!sm->dstack.empty() && !dstack_check(sm, element)) {
    dstack_rewind(sm);
  }

  dstack_rewind(sm);
}

static void dstack_open_list(StateMachine * sm, int depth) {
  g_debug("open list");

  if (dstack_is_open(sm, BLOCK_LI)) {
    dstack_close_until(sm, BLOCK_LI);
  } else {
    dstack_close_leaf_blocks(sm);
  }

  while (dstack_count(sm, BLOCK_UL) < depth) {
    dstack_open_block(sm, BLOCK_UL, "<ul>");
  }

  while (dstack_count(sm, BLOCK_UL) > depth) {
    dstack_close_until(sm, BLOCK_UL);
  }

  dstack_open_block(sm, BLOCK_LI, "<li>");
}

static void dstack_close_list(StateMachine * sm) {
  while (dstack_is_open(sm, BLOCK_UL)) {
    dstack_close_until(sm, BLOCK_UL);
  }
}

static inline std::tuple<char32_t, int> get_utf8_char(const char* c) {
  const unsigned char* p = reinterpret_cast<const unsigned char*>(c);

  // 0x10xxxxxx is a continuation byte; back up to the leading byte.
  while ((p[0] >> 6) == 0b10) {
    p--;
  }

  if (p[0] >> 7 == 0) {
    // 0x0xxxxxxx
    return { p[0], 1 };
  } else if ((p[0] >> 5) == 0b110) {
    // 0x110xxxxx, 0x10xxxxxx
    return { ((p[0] & 0b00011111) << 6) | (p[1] & 0b00111111), 2 };
  } else if ((p[0] >> 4) == 0b1110) {
    // 0x1110xxxx, 0x10xxxxxx, 0x10xxxxxx
    return { ((p[0] & 0b00001111) << 12) | (p[1] & 0b00111111) << 6 | (p[2] & 0b00111111), 3 };
  } else if ((p[0] >> 3) == 0b11110) {
    // 0x11110xxx, 0x10xxxxxx, 0x10xxxxxx, 0x10xxxxxx
    return { ((p[0] & 0b00000111) << 18) | (p[1] & 0b00111111) << 12 | (p[2] & 0b00111111) << 6 | (p[3] & 0b00111111), 4 };
  } else {
    return { 0, 0 };
  }
}

// Returns the preceding non-boundary character if `c` is a boundary character.
// Otherwise, returns `c` if `c` is not a boundary character. Boundary characters
// are trailing punctuation characters that should not be part of the matched text.
static inline const char* find_boundary_c(const char* c) {
  auto [ch, len] = get_utf8_char(c);

  if (std::binary_search(std::begin(boundary_characters), std::end(boundary_characters), ch)) {
    return c - len;
  } else {
    return c;
  }
}

StateMachine::StateMachine(const char * src, size_t len, int initial_state, const DTextOptions options) : options(options) {
  output.reserve(len * 1.5);
  stack.reserve(16);
  dstack.reserve(16);
  posts.reserve(10);

  p = src;
  pb = p;
  pe = p + len;
  eof = pe;
  cs = initial_state;
}

std::string StateMachine::parse_basic_inline(const char* src, const size_t len) {
    DTextOptions options = {};
    options.f_inline = true;
    options.allow_color = false;
    options.max_thumbs = 0;

    StateMachine sm(src, len, dtext_en_basic_inline, options);

    return sm.parse().dtext;
}

DTextResult StateMachine::parse_dtext(const char* src, const size_t len, DTextOptions options) {
  StateMachine sm(src, len, dtext_en_main, options);
  return sm.parse();
}

DTextResult StateMachine::parse() {
  StateMachine* sm = this;
  g_debug("start\n");

  %% write init nocs;
  %% write exec;

  dstack_close_all(sm);

  return DTextResult { sm->output, sm->posts };
}
