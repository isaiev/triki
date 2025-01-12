require "../spec_helper"

Spectator.describe Triki::Postgres do
  describe "#rows_to_be_inserted" do
    it "splits tab seperated values" do
      line = "1	2	3	4"
      expect(subject.rows_to_be_inserted(line)).to eq([["1", "2", "3", "4"]])
    end

    it "preserves empty strings at the end of a line" do
      line = "1	2	3	4	"
      expect(subject.rows_to_be_inserted(line)).to eq([["1", "2", "3", "4", ""]])
    end

    it "ignores the newline character at the end of string" do
      line = "1	2	3	4\n"
      expect(subject.rows_to_be_inserted(line)).to eq([["1", "2", "3", "4"]])
    end

    it "does not ignore newlines due to empty strings" do
      line = "1	2	3	\n"
      expect(subject.rows_to_be_inserted(line)).to eq([["1", "2", "3", ""]])
    end

    it "does not ignore newline characters in the string" do
      line = "1	2	3\n4	5"
      expect(subject.rows_to_be_inserted(line)).to eq([["1", "2", "3\n4", "5"]])
    end

    it "preserves empty strings in the middle of the string" do
      line = "1	2		4"
      expect(subject.rows_to_be_inserted(line)).to eq([["1", "2", "", "4"]])
    end

    it "preserves newline characters in the middle of the string" do
      line = "1	2	\n	4"
      expect(subject.rows_to_be_inserted(line)).to eq([["1", "2", "\n", "4"]])
    end

    it "replaces \\N with nil" do
      line = "1	2	\\N	4"
      expect(subject.rows_to_be_inserted(line)).to eq([["1", "2", nil, "4"]])
    end

    it "replaces \\N\n with nil" do
      line = "1	2	3	\\N\n"
      expect(subject.rows_to_be_inserted(line)).to eq([["1", "2", "3", nil]])
    end
  end

  describe "#parse_copy_statement" do
    it "parses table name and column names" do
      line = "COPY some_table (id, email, name, something) FROM stdin;"
      hash = subject.parse_copy_statement(line) || raise "Error"
      expect(hash["table_name"]).to eq("some_table")
      expect(hash["column_names"]).to eq(["id", "email", "name", "something"])
    end
  end

  describe "#make_insert_statement" do
    it "creates a string with tab delminted" do
      expect(subject.make_insert_statement("some_table", ["id", "name"], ["1", "2"])).to eq("1	2")
    end
  end
end
