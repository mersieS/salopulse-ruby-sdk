module Salopulse
  module LocalFingerprint
    module_function

    def for(sql)
      sql.to_s
        .downcase
        .gsub(/'[^']*'/, "?")
        .gsub(/\b\d+(\.\d+)?\b/, "?")
        .gsub(/\bin\s*\([^)]+\)/, "in (?)")
        .gsub(/\s+/, " ")
        .strip
    end
  end
end
