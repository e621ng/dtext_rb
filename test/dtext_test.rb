require 'minitest/autorun'
require 'dtext/dtext'

class DTextTest < Minitest::Test
  def assert_parse_id_link(class_name, url, input, display: nil)
    assert_parse(%{<p><a class="dtext-link dtext-id-link #{class_name}" href="#{url}">#{display ? display : input}</a></p>}, input)
  end

  def assert_parse(expected, input, **options)

    if expected.nil?
      assert_nil(str_part = DTextRagel.parse(input, **options))
    else
      str_part = DTextRagel.parse(input, **options)[0]
      assert_equal(expected, str_part)
    end
  end

  def assert_color(prefix, color)
    str_part = DTextRagel.parse("[color=#{color}]test[/color]", allow_color: true)[0]
    assert_equal("#{prefix}#{color}\">test</span></p>", str_part)
  end

  def test_legacy_table
    assert_parse("<table class=\"striped\"><thead><tr><th>test1 \\| test2 </th><th> test2</th></tr></thead><tbody><tr><td>abc </td><td> 123</td></tr></tbody></table>", <<~END
[ltable]
test1 \\| test2 | test2
abc | 123
[/ltable]
    END
    )
    assert_parse("<table class=\"striped\"><thead><tr><th>test1 </th><th> test2</th></tr></thead><tbody><tr><td>abc </td><td> 123</td></tr></tbody></table><table class=\"striped\"><thead><tr><th>test1 </th><th> test2</th></tr></thead><tbody><tr><td>abc </td><td> 123</td></tr></tbody></table>", <<~END
[ltable]
test1 | test2
abc | 123
[/ltable]
[ltable]
test1 | test2
abc | 123
[/ltable]
    END
    )
    assert_parse("<table class=\"striped\"><thead><tr><th>test1</th></tr></thead><tbody></tbody></table>", <<~END
[ltable]
test1
[/ltable]
    END
    )
    assert_parse("<table class=\"striped\"><thead><tr><th>test1</th></tr></thead><tbody><tr><td>test2</td></tr></tbody></table>", <<~END
[ltable]test1
test2[/ltable]
    END
    )
  end

  def test_relative_urls
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-post-id-link" href="http://danbooru.donmai.us/posts/1234">post #1234</a></p>', "post #1234", base_url: "http://danbooru.donmai.us")
    assert_parse('<p><a rel="nofollow" class="dtext-link" href="http://danbooru.donmai.us/posts">posts</a></p>', '"posts":/posts', base_url: "http://danbooru.donmai.us")
    assert_parse('<p><a rel="nofollow" href="http://danbooru.donmai.us/users?name=evazion">@evazion</a></p>', "@evazion", base_url: "http://danbooru.donmai.us")
  end

  def test_thumbnails
    parsed = DTextRagel.parse("thumb #123")
    assert_equal(parsed[1], [123])
    assert_equal(parsed[0], "<p><a class=\"dtext-link dtext-id-link dtext-post-id-link thumb-placeholder-link\" data-id=\"123\" href=\"/posts/123\">post #123</a></p>")
    parsed = DTextRagel.parse("thumb #123 "*10, max_thumbs: 5)
    assert_equal(parsed[1], [123]*5)
  end

  def test_args
    assert_parse(nil, nil)
    assert_parse("", "")
    assert_raises(TypeError) { DTextRagel.parse(42) }
  end

  def test_mentions
    assert_parse('<p><a rel="nofollow" href="/users?name=bob">@bob</a></p>', "@bob")
    assert_parse('<p>hi <a rel="nofollow" href="/users?name=bob">@bob</a></p>', "hi @bob")
    assert_parse('<p>this is not @.@ @_@ <a rel="nofollow" href="/users?name=bob">@bob</a></p>', "this is not @.@ @_@ @bob")
    assert_parse('<p>this is an email@address.com and should not trigger</p>', "this is an email@address.com and should not trigger")
    assert_parse('<p>multiple <a rel="nofollow" href="/users?name=bob">@bob</a> <a rel="nofollow" href="/users?name=anna">@anna</a></p>', "multiple @bob @anna")
    assert_equal('<p>hi @bob</p>', DTextRagel.parse("hi @bob", :disable_mentions => true)[0])
  end

  def test_nested_nonmention
    assert_parse('<p>foo <strong>idolm@ster</strong> bar</p>', 'foo [b]idolm@ster[/b] bar')
  end

  def test_sanitize_heart
    assert_parse('<p>&lt;3</p>', "<3")
  end

  def test_sanitize_less_than
    assert_parse('<p>&lt;</p>', "<")
  end

  def test_sanitize_greater_than
    assert_parse('<p>&gt;</p>', ">")
  end

  def test_sanitize_ampersand
    assert_parse('<p>&amp;</p>', "&")
  end

  def test_wiki_links
    assert_parse("<p>a <a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=b\">b</a> c</p>", "a [[b]] c")
  end

  def test_wiki_links_spoiler
    assert_parse("<p>a <a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=spoiler\">spoiler</a> c</p>", "a [[spoiler]] c")
  end

  def test_wiki_links_aliased
    assert_parse("<p><a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=wiki_page\">Some Text</a></p>", "[[wiki page|Some Text]]")
  end

  def test_wiki_links_edge
    assert_parse("<p>[[|_|]]</p>", "[[|_|]]")
    assert_parse("<p>[[||_||]]</p>", "[[||_||]]")
  end

  def test_wiki_links_nested_b
    assert_parse("<p><strong>[[</strong>tag<strong>]]</strong></p>", "[b][[[/b]tag[b]]][/b]")
  end

  def test_spoilers_inline
    assert_parse("<p>this is <span class=\"spoiler\">an inline spoiler</span>.</p>", "this is [spoiler]an inline spoiler[/spoiler].")
  end

  def test_spoilers_inline_plural
    assert_parse("<p>this is <span class=\"spoiler\">an inline spoiler</span>.</p>", "this is [SPOILERS]an inline spoiler[/SPOILERS].")
  end

  def test_spoilers_block
    assert_parse("<p>this is</p><div class=\"spoiler\"><p>a block spoiler</p></div><p>.</p>", "this is\n\n[spoiler]\na block spoiler\n[/spoiler].")
  end

  def test_spoilers_block_plural
    assert_parse("<p>this is</p><div class=\"spoiler\"><p>a block spoiler</p></div><p>.</p>", "this is\n\n[SPOILERS]\na block spoiler\n[/SPOILERS].")
  end

  def test_spoilers_with_no_closing_tag_1
    assert_parse("<div class=\"spoiler\"><p>this is a spoiler with no closing tag</p><p>new text</p></div>", "[spoiler]this is a spoiler with no closing tag\n\nnew text")
  end

  def test_spoilers_with_no_closing_tag_2
    assert_parse("<div class=\"spoiler\"><p>this is a spoiler with no closing tag<br>new text</p></div>", "[spoiler]this is a spoiler with no closing tag\nnew text")
  end

  def test_spoilers_with_no_closing_tag_block
    assert_parse("<div class=\"spoiler\"><p>this is a block spoiler with no closing tag</p></div>", "[spoiler]\nthis is a block spoiler with no closing tag")
  end

  def test_spoilers_nested
    assert_parse("<div class=\"spoiler\"><p>this is <span class=\"spoiler\">a nested</span> spoiler</p></div>", "[spoiler]this is [spoiler]a nested[/spoiler] spoiler[/spoiler]")
  end

  def test_sub_sup
    assert_parse("<p><sub>test</sub></p>", "[sub]test[/sub]")
    assert_parse("<p><sup>test</sup></p>", "[sup]test[/sup]")
    assert_parse("<p><sub><sub>test</sub></sub></p>", "[sub][sub]test[/sub][/sub]")
    assert_parse("<p><sup><sup>test</sup></sup></p>", "[sup][sup]test[/sup][/sup]")
  end

  def test_color
    %w(art artist char character spec species copy copyright inv invalid meta lore).each do |color|
      assert_color("<p><span class=\"dtext-color-", color)
    end
    assert_color("<p><span class=\"dtext-color\" style=\"color:", 'yellow')
    assert_color("<p><span class=\"dtext-color\" style=\"color:", "#ccc")
    assert_color("<p><span class=\"dtext-color\" style=\"color:", "#12345")
    assert_color("<p><span class=\"dtext-color\" style=\"color:", "#1a1")
  end

  def test_color_not_allowed
    assert_parse("<p>test</p>", "[color=invalid]test[/color]")
    assert_parse("<p>test</p>", "[color=#123456]test[/color]")
  end

  def test_nested_inline_code
    assert_parse(%{<span class="inline-code">`what`</span>}, "`\\`what\\``")
  end

  def test_paragraphs
    assert_parse("<p>abc</p>", "abc")
  end

  def test_paragraphs_with_newlines_1
    assert_parse("<p>a<br>b<br>c</p>", "a\nb\nc")
  end

  def test_paragraphs_with_newlines_2
    assert_parse("<p>a</p><p>b</p>", "a\n\nb")
  end

  def test_headers
    assert_parse("<h1>header</h1>", "h1. header")
    assert_parse("<ul><li>a</li></ul><h1>header</h1><ul><li>list</li></ul>", "* a\n\nh1. header\n* list")
  end

  def test_inline_headers
    assert_parse("<p>blah h1. blah</p>", "blah h1. blah")
  end

  def test_headers_with_ids
    assert_parse("<h1 id=\"dtext-blah-blah\">header</h1>", "h1#blah-blah. header")
  end

  def test_headers_with_ids_with_quote
    assert_parse("<p>h1#blah-&quot;blah. header</p>", "h1#blah-\"blah. header")
  end

  def test_inline_tn
    assert_parse('<p>foo <span class="tn">bar</span></p>', "foo [tn]bar[/tn]")
  end

  def test_block_tn
    assert_parse('<p class="tn">bar</p>', "[tn]bar[/tn]")
  end

  def test_quote_blocks
    assert_parse('<blockquote><p>test</p></blockquote>', "[quote]\ntest\n[/quote]")
  end

  def test_quote_blocks_with_list
    assert_parse("<blockquote><ul><li>hello</li><li>there<br></li></ul></blockquote><p>abc</p>", "[quote]\n* hello\n* there\n[/quote]\nabc")
    assert_parse("<blockquote><ul><li>hello</li><li>there</li></ul></blockquote><p>abc</p>", "[quote]\n* hello\n* there\n\n[/quote]\nabc")
  end

  def test_quote_blocks_nested
    assert_parse("<blockquote><p>a</p><blockquote><p>b</p></blockquote><p>c</p></blockquote>", "[quote]\na\n[quote]\nb\n[/quote]\nc\n[/quote]")
  end

  def test_quote_blocks_nested_spoiler
    assert_parse("<blockquote><p>a<br><span class=\"spoiler\">blah</span><br>c</p></blockquote>", "[quote]\na\n[spoiler]blah[/spoiler]\nc[/quote]")
    assert_parse("<blockquote><p>a</p><div class=\"spoiler\"><p>blah</p></div><p>c</p></blockquote>", "[quote]\na\n\n[spoiler]blah[/spoiler]\n\nc[/quote]")
  end

  def test_quote_blocks_nested_expand
    assert_parse("<blockquote><p>a</p><div class=\"expandable\"><div class=\"expandable-header\"><span class=\"section-arrow\"></span></div><div class=\"expandable-content\"><p>b</p></div></div><p>c</p></blockquote>", "[quote]\na\n[section]\nb\n[/section]\nc\n[/quote]")
  end

  def test_code
    assert_parse("<pre>for (i=0; i&lt;5; ++i) {\n  printf(1);\n}\n\nexit(1);</pre>", "[code]for (i=0; i<5; ++i) {\n  printf(1);\n}\n\nexit(1);")
  end

  def test_urls
    assert_parse('<p>a <a rel="nofollow" class="dtext-link" href="http://test.com">http://test.com</a> b</p>', 'a http://test.com b')
  end

  def test_urls_with_newline
    assert_parse('<p><a rel="nofollow" class="dtext-link" href="http://test.com">http://test.com</a><br>b</p>', "http://test.com\nb")
  end

  def test_urls_with_paths
    assert_parse('<p>a <a rel="nofollow" class="dtext-link" href="http://test.com/~bob/image.jpg">http://test.com/~bob/image.jpg</a> b</p>', 'a http://test.com/~bob/image.jpg b')
  end

  def test_urls_with_fragment
    assert_parse('<p>a <a rel="nofollow" class="dtext-link" href="http://test.com/home.html#toc">http://test.com/home.html#toc</a> b</p>', 'a http://test.com/home.html#toc b')
  end

  def test_auto_urls
    assert_parse('<p>a <a rel="nofollow" class="dtext-link" href="http://test.com">http://test.com</a>. b</p>', 'a http://test.com. b')
  end

  def test_auto_urls_in_parentheses
    assert_parse('<p>a (<a rel="nofollow" class="dtext-link" href="http://test.com">http://test.com</a>) b</p>', 'a (http://test.com) b')
  end

  def test_old_style_links
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-external-link" href="http://test.com">test</a></p>', '"test":http://test.com')
  end

  def test_old_style_links_with_inline_tags
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-external-link" href="http://test.com"><em>test</em></a></p>', '"[i]test[/i]":http://test.com')
  end

  def test_old_style_links_with_nested_links
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-external-link" href="http://test.com">post #1</a></p>', '"post #1":http://test.com')
  end

  def test_old_style_links_with_special_entities
    assert_parse('<p>&quot;1&quot; <a rel="nofollow" class="dtext-link dtext-external-link" href="http://three.com">2 &amp; 3</a></p>', '"1" "2 & 3":http://three.com')
  end

  def test_new_style_links
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-external-link" href="http://test.com">test</a></p>', '"test":[http://test.com]')
  end

  def test_new_style_links_with_inline_tags
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-external-link" href="http://test.com/(parentheses)"><em>test</em></a></p>', '"[i]test[/i]":[http://test.com/(parentheses)]')
  end

  def test_new_style_links_with_nested_links
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-external-link" href="http://test.com">post #1</a></p>', '"post #1":[http://test.com]')
  end

  def test_new_style_links_with_parentheses
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-external-link" href="http://test.com/(parentheses)">test</a></p>', '"test":[http://test.com/(parentheses)]')
    assert_parse('<p>(<a rel="nofollow" class="dtext-link dtext-external-link" href="http://test.com/(parentheses)">test</a>)</p>', '("test":[http://test.com/(parentheses)])')
    assert_parse('<p>[<a rel="nofollow" class="dtext-link dtext-external-link" href="http://test.com/(parentheses)">test</a>]</p>', '["test":[http://test.com/(parentheses)]]')
  end

  def test_fragment_only_urls
    assert_parse('<p><a rel="nofollow" class="dtext-link" href="#toc">test</a></p>', '"test":#toc')
    assert_parse('<p><a rel="nofollow" class="dtext-link" href="#toc">test</a></p>', '"test":[#toc]')
  end

  def test_auto_url_boundaries
    assert_parse('<p>a （<a rel="nofollow" class="dtext-link" href="http://test.com">http://test.com</a>） b</p>', 'a （http://test.com） b')
    assert_parse('<p>a 〜<a rel="nofollow" class="dtext-link" href="http://test.com">http://test.com</a>〜 b</p>', 'a 〜http://test.com〜 b')
    assert_parse('<p>a <a rel="nofollow" class="dtext-link" href="http://test.com">http://test.com</a>　 b</p>', 'a http://test.com　 b')
  end

  def test_old_style_link_boundaries
    assert_parse('<p>a 「<a rel="nofollow" class="dtext-link dtext-external-link" href="http://test.com">title</a>」 b</p>', 'a 「"title":http://test.com」 b')
  end

  def test_new_style_link_boundaries
    assert_parse('<p>a 「<a rel="nofollow" class="dtext-link dtext-external-link" href="http://test.com">title</a>」 b</p>', 'a 「"title":[http://test.com]」 b')
  end

  def test_lists_1
    assert_parse('<ul><li>a</li></ul>', '* a')
  end

  def test_lists_2
    assert_parse('<ul><li>a</li><li>b</li></ul>', "* a\n* b")
  end

  def test_lists_nested
    assert_parse('<ul><li>a</li><ul><li>b</li></ul></ul>', "* a\n** b")
  end

  def test_lists_inline
    assert_parse('<ul><li><a class="dtext-link dtext-id-link dtext-post-id-link" href="/posts/1">post #1</a></li></ul>', "* post #1")
  end

  def test_lists_not_preceded_by_newline
    assert_parse('<p>a<br>b</p><ul><li>c</li><li>d</li></ul>', "a\nb\n* c\n* d")
  end

  def test_lists_with_multiline_items
    assert_parse('<p>a</p><ul><li>b<br>c</li><li>d<br>e</li></ul><p>another one</p>', "a\n* b\nc\n* d\ne\n\nanother one")
    assert_parse('<p>a</p><ul><li>b<br>c</li><ul><li>d<br>e</li></ul></ul><p>another one</p>', "a\n* b\nc\n** d\ne\n\nanother one")
  end

  def test_inline_tags
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-post-search-link" href="/posts?tags=tag">tag</a></p>', "{{tag}}")
    assert_parse('<p>hello </p><pre>tag</pre>', "hello [code]tag[/code]")
  end

  def test_inline_tags_conjunction
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-post-search-link" href="/posts?tags=tag1%20tag2">tag1 tag2</a></p>', "{{tag1 tag2}}")
  end

  def test_inline_tags_special_entities
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-post-search-link" href="/posts?tags=%3C3">&lt;3</a></p>', "{{<3}}")
  end

  def test_inline_tags_aliased
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-post-search-link" href="/posts?tags=fox%20smile">Best Search</a></p>', "{{fox smile|Best Search}}")
  end

  def test_extra_newlines
    assert_parse('<p>a</p><p>b</p>', "a\n\n\n\n\n\n\nb\n\n\n\n")
  end

  def test_complex_links_1
    assert_parse("<p><a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=1\">2 3</a> | <a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=4\">5 6</a></p>", "[[1|2 3]] | [[4|5 6]]")
  end

  def test_complex_links_2
    assert_parse("<p>Tags <strong>(<a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=howto%3Atag\">Tagging Guidelines</a> | <a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=howto%3Atag_checklist\">Tag Checklist</a> | <a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=tag_groups\">Tag Groups</a>)</strong></p>", "Tags [b]([[howto:tag|Tagging Guidelines]] | [[howto:tag_checklist|Tag Checklist]] | [[Tag Groups]])[/b]")
  end

  def test_anchored_wiki_link
    assert_parse("<p><a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=avoid_posting#a\">ABC 123</a></p>", "[[avoid_posting#A|ABC 123]]")
  end

  def test_internal_anchor
    assert_parse("<p><a id=\"b\"></a></p>", "[#B]")
  end

  def text_note_id_link
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-note-id-link" href="/notes/1234">note #1234</a></p>', "note #1234")
  end

  def test_table
    assert_parse("<table class=\"striped\"><thead><tr><th>header</th></tr></thead><tbody><tr><td><a class=\"dtext-link dtext-id-link dtext-post-id-link\" href=\"/posts/100\">post #100</a></td></tr></tbody></table>", "[table][thead][tr][th]header[/th][/tr][/thead][tbody][tr][td]post #100[/td][/tr][/tbody][/table]")
  end

  def test_table_with_newlines
    assert_parse("<table class=\"striped\"><thead><tr><th>header</th></tr></thead><tbody><tr><td><a class=\"dtext-link dtext-id-link dtext-post-id-link\" href=\"/posts/100\">post #100</a></td></tr></tbody></table>", "[table]\n[thead]\n[tr]\n[th]header[/th][/tr][/thead][tbody][tr][td]post #100[/td][/tr][/tbody][/table]")
  end

  def test_unclosed_th
    assert_parse('<table class="striped"><th>foo</th></table>', "[table][th]foo")
  end

  def test_forum_links
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-forum-topic-id-link" href="/forum_topics/1234?page=4">topic #1234/p4</a></p>', "topic #1234/p4")
  end

  def test_id_links
    assert_parse_id_link("dtext-post-id-link", "/posts/1234", "post #1234")
    assert_parse_id_link("dtext-post-changes-for-id-link", "/post_versions?search[post_id]=1234", "post changes #1234")
    assert_parse_id_link("dtext-post-flag-id-link", "/post_flags/1234", "flag #1234")
    assert_parse_id_link("dtext-note-id-link", "/notes/1234", "note #1234")
    assert_parse_id_link("dtext-forum-post-id-link", "/forum_posts/1234", "forum #1234")
    assert_parse_id_link("dtext-forum-topic-id-link", "/forum_topics/1234", "topic #1234")
    assert_parse_id_link("dtext-comment-id-link", "/comments/1234", "comment #1234")
    assert_parse_id_link("dtext-pool-id-link", "/pools/1234", "pool #1234")
    assert_parse_id_link("dtext-user-id-link", "/users/1234", "user #1234")
    assert_parse_id_link("dtext-artist-id-link", "/artists/1234", "artist #1234")
    assert_parse_id_link("dtext-ban-id-link", "/bans/1234", "ban #1234")
    assert_parse_id_link("dtext-tag-alias-id-link", "/tag_aliases/1234", "alias #1234")
    assert_parse_id_link("dtext-tag-implication-id-link", "/tag_implications/1234", "implication #1234")
    assert_parse_id_link("dtext-mod-action-id-link", "/mod_actions/1234", "mod action #1234")
    assert_parse_id_link("dtext-user-feedback-id-link", "/user_feedbacks/1234", "record #1234")
    assert_parse_id_link("dtext-blip-id-link", "/blips/1234", "blip #1234")
    assert_parse_id_link("dtext-set-id-link", "/post_sets/1234", "set #1234")
    assert_parse_id_link("dtext-takedown-id-link", "/takedowns/1234", "takedown #1234")
    assert_parse_id_link("dtext-takedown-id-link", "/takedowns/1234", "take down #1234", display: "takedown #1234")
    assert_parse_id_link("dtext-takedown-id-link", "/takedowns/1234", "takedown request #1234", display: "takedown #1234")
    assert_parse_id_link("dtext-takedown-id-link", "/takedowns/1234", "take down request #1234", display: "takedown #1234")
    assert_parse_id_link("dtext-ticket-id-link", "/tickets/1234", "ticket #1234")
    assert_parse_id_link("dtext-wiki-page-id-link", "/wiki_pages/1234", "wiki #1234")
  end

  def test_boundary_exploit
    assert_parse('<p><a rel="nofollow" href="/users?name=mack">@mack</a>&lt;</p>', "@mack<")
  end

  def test_expand
    assert_parse("<div class=\"expandable\"><div class=\"expandable-header\"><span class=\"section-arrow\"></span></div><div class=\"expandable-content\"><p>hello world</p></div></div>", "[section]hello world[/section]")
  end

  def test_aliased_expand
    assert_parse("<div class=\"expandable\"><div class=\"expandable-header\"><span class=\"section-arrow\"></span><span>hello</span></div><div class=\"expandable-content\"><p>blah blah</p></div></div>", "[section=hello]blah blah[/section]")
  end

  def test_expand_with_nested_code
    assert_parse("<div class=\"expandable\"><div class=\"expandable-header\"><span class=\"section-arrow\"></span></div><div class=\"expandable-content\"><pre>hello\n</pre></div></div>", "[section]\n[code]\nhello\n[/code]\n[/section]")
  end

  def test_expand_with_nested_list
    assert_parse("<div class=\"expandable\"><div class=\"expandable-header\"><span class=\"section-arrow\"></span></div><div class=\"expandable-content\"><ul><li>a</li><li>b<br></li></ul></div></div><p>c</p>", "[section]\n* a\n* b\n[/section]\nc")
  end

  def test_inline_mode
    assert_equal("hello", DTextRagel.parse_inline("hello")[0].strip)
  end

  def test_old_asterisks
    assert_parse("<p>hello *world* neutral</p>", "hello *world* neutral")
  end

  def test_utf8_mentions
    assert_parse('<p><a rel="nofollow" href="/users?name=葉月">@葉月</a></p>', "@葉月")
    assert_parse('<p>Hello <a rel="nofollow" href="/users?name=葉月">@葉月</a> and <a rel="nofollow" href="/users?name=Alice">@Alice</a></p>', "Hello @葉月 and @Alice")
    assert_parse('<p>Should not parse 葉月@葉月</p>', "Should not parse 葉月@葉月")
  end

  def test_mention_boundaries
    assert_parse('<p>「hi <a rel="nofollow" href="/users?name=葉月">@葉月</a>」</p>', "「hi @葉月」")
  end

  def test_delimited_mentions
    dtext = '(blah <@evazion>).'
    html = '<p>(blah <a rel="nofollow" href="/users?name=evazion">@evazion</a>).</p>'
    assert_parse(html, dtext)
  end

  def test_utf8_links
    assert_parse('<p><a rel="nofollow" class="dtext-link" href="/posts?tags=approver:葉月">7893</a></p>', '"7893":/posts?tags=approver:葉月')
    assert_parse('<p><a rel="nofollow" class="dtext-link" href="/posts?tags=approver:葉月">7893</a></p>', '"7893":[/posts?tags=approver:葉月]')
    assert_parse('<p><a rel="nofollow" class="dtext-link" href="http://danbooru.donmai.us/posts?tags=approver:葉月">http://danbooru.donmai.us/posts?tags=approver:葉月</a></p>', 'http://danbooru.donmai.us/posts?tags=approver:葉月')
  end

  def test_delimited_links
    dtext = '(blah <https://en.wikipedia.org/wiki/Orange_(fruit)>).'
    html = '<p>(blah <a rel="nofollow" class="dtext-link" href="https://en.wikipedia.org/wiki/Orange_(fruit)">https://en.wikipedia.org/wiki/Orange_(fruit)</a>).</p>'
    assert_parse(html, dtext)
  end

  def test_nodtext
    assert_parse('<p>[b]not bold[/b]</p><p> <strong>bold</strong></p>', "[nodtext][b]not bold[/b][/nodtext] [b]bold[/b]")
    assert_parse('<p>[b]not bold[/b]</p><p><strong>hello</strong></p>', "[nodtext][b]not bold[/b][/nodtext]\n\n[b]hello[/b]")
    assert_parse('<p> [b]not bold[/b]</p>', " [nodtext][b]not bold[/b][/nodtext]")
  end

  def test_stack_depth_limit
    assert_raises(DTextRagel::Error) { DTextRagel.parse("* foo\n" * 513) }
  end

  def test_null_bytes
    assert_raises(DTextRagel::Error) { DTextRagel.parse("foo\0bar") }
  end

  def test_wiki_link_xss
    assert_raises(DTextRagel::Error) do
      DTextRagel.parse("[[\xFA<script \xFA>alert(42); //\xFA</script \xFA>]]")
    end
  end

  def test_mention_xss
    assert_raises(DTextRagel::Error) do
      DTextRagel.parse("@user\xF4<b>xss\xFA</b>")
    end
  end

  def test_url_xss
    assert_raises(DTextRagel::Error) do
      DTextRagel.parse(%("url":/page\xF4">x\xFA<b>xss\xFA</b>))
    end
  end
end
