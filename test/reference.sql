SET STATEMENT_TIMEOUT = 0;
@export {"type": "json", "processor": { "printTableName": false } }

SELECT 'wp' || id as id, body FROM wiki_pages
UNION ALL SELECT 'pf' || id, reason FROM post_flags
UNION ALL SELECT 'bl' || id, body FROM blips
UNION ALL SELECT 'cm' || id, body FROM comments
UNION ALL SELECT 'fp' || id, body FROM forum_posts
UNION ALL SELECT 'uf' || id, body FROM user_feedback
UNION ALL SELECT 'no' || id, body FROM notes
UNION ALL SELECT 'po' || id, description FROM pools
UNION ALL SELECT 'ps' || id, description FROM post_sets
UNION ALL SELECT 'ua' || id, profile_about FROM users WHERE profile_about IS NOT NULL AND profile_about != ''
UNION ALL SELECT 'ui' || id, profile_artinfo FROM users WHERE profile_artinfo IS NOT NULL AND profile_artinfo != ''
UNION ALL SELECT 'pd' || id, description FROM posts WHERE description IS NOT NULL AND description != '';

-- tr -d '\0-\10\13\14\16-\37' < export.json > dtext.json
-- jq -c '.[]' dtext.json | gzip > dtext.json.gz
