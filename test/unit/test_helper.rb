module DTextTestHelper
  def assert_parse(expected, input, **options)
    if expected.nil?
      assert_nil(str_part = DText.parse(input, **options))
    else
      str_part = DText.parse(input, **options)[0]
      assert_equal(expected, str_part)
    end
  end
end
