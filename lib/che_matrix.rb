##[>] 🤖🤖
require "yaml"

# Compares the che profiles a repo publishes against the profiles its CI
# includes feed to the shared matrix templates.
module CheMatrix
  PROFILES_KEY = "profilesDefinitions"
  EXEMPT_MARK = "matrix-exempt"
  TEMPLATE_MARK = "CheProfile"

  Diff = Struct.new(:uncovered, :unpublished, keyword_init: true) do
    def clean?
      uncovered.empty? && unpublished.empty?
    end
  end

  # published returns every profile name the given che spec bodies define
  # under profilesDefinitions, minus keys marked "# matrix-exempt".
  def self.published(spec_bodies)
    spec_bodies.flat_map { |body| published_in(body) }.uniq
  end

  # covered returns the profile names a CI config's shared-template includes
  # pass through inputs.profiles.
  def self.covered(ci_yaml)
    template_includes(ci_yaml)
      .flat_map { |entry| Array(entry.dig("inputs", "profiles")) }
      .map(&:to_s)
      .uniq
  end

  def self.diff(published, covered)
    Diff.new(uncovered: published - covered, unpublished: covered - published)
  end

  def self.published_in(spec_yaml)
    exempt = exempt_keys(spec_yaml)
    profile_keys(spec_yaml).reject { |key| exempt.include?(key) }
  end

  def self.profile_keys(spec_yaml)
    doc = YAML.safe_load(spec_yaml, aliases: true)
    profiles = doc.is_a?(Hash) ? doc[PROFILES_KEY] : nil
    profiles.is_a?(Hash) ? profiles.keys.map(&:to_s) : []
  end

  def self.exempt_keys(spec_yaml)
    spec_yaml.lines.filter_map do |line|
      key, comment = line.split("#", 2)
      next unless comment.to_s.include?(EXEMPT_MARK)

      key.to_s[/\A\s*['"]?([A-Za-z][\w\/.-]*)['"]?:/, 1]
    end
  end

  def self.template_includes(ci_yaml)
    doc = YAML.safe_load(ci_yaml, aliases: true)
    entries = doc.is_a?(Hash) ? Array(doc["include"]) : []
    entries.select do |entry|
      entry.is_a?(Hash) && %w[local file].any? { |k| entry[k].to_s.include?(TEMPLATE_MARK) }
    end
  end
end
##[<] 🤖🤖
