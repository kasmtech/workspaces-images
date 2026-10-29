[ .[]
  | select(.draft == false and .prerelease == false)
  | . as $rel
  | .assets[]
  | select(.name | endswith("AppImage"))
  | select(.digest != null)
  | select(if $arch == "arm64"
           then (.name | contains("arm64"))
           else (.name | contains("arm64") | not) end)
  | "\($rel.tag_name)\t\(.browser_download_url)\t\(.digest)"
] | first // empty
