require 'spec_helper'

describe Furi::Uri do

  describe ".rfc3986?" do

    it "works" do
      expect(Furi.parse("http://goo gl.com") ).to_not be_rfc
      expect(Furi.parse("http://googl.com") ).to be_rfc
    end
  end
end
