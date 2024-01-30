# Copyright(c) 2015-2024 ACCESS CO., LTD. All rights reserved.

defmodule AntikytheraAws.S3Test do
  use Croma.TestCase

  test "generate_signature/5 should return correct signature" do
    signature =
      S3.generate_signature("test-bucket", "test-key", "test_secret", "token", 1_234_567_890)

    assert signature == "ngAeEE4w0w1NaUYkwEk1iARwn6Q="
  end
end
