module System
  def self.puts(*); end
end
class Hash
  class_eval <<~RUBY, "[Luka's Scripting Utilities] script.rb", 175
    def has_key?(*args)
      for key in args
        return false if !self.keys.include?(key)
      end
      true
    end
  RUBY
end
legacy = Hash.instance_method(:has_key?)
load File.expand_path('../pak/emulators/mkxp-z/profiles/pokemon-sa-performance.rb', __dir__)
module PluginManager
  def self.runPlugins; end
end
PluginManager.runPlugins
raise 'fast path not installed' unless Hash.ancestors.include?(LeafSAPerformance::FastHashMembership)

normal = { :present => nil, :false_value => false, 1 => :integer, 2.0 => :float,
           'text' => :string, nil => :nil }
identity = {}.compare_by_identity
identity['same'.dup] = true
identity[:present] = false
custom_key = Object.new
def custom_key.==(other); other == :missing; end
custom = { custom_key => true }
checks = 0
[{}, normal, identity, custom].each do |hash|
  keys = [:present, :false_value, :missing, 1, 1.0, 2, 2.0, 'text', 'same', nil, custom_key]
  queries = [[]] + keys.map { |key| [key] } + keys.product(keys)
  queries.each do |query|
    expected = legacy.bind(hash).call(*query)
    actual = hash.has_key?(*query)
    raise "legacy membership mismatch for #{query.inspect}" unless actual == expected
    checks += 1
  end
end
no_allocation = { :present => false, 1 => nil }
def no_allocation.keys; raise 'fast successful lookup allocated a keys array'; end
raise 'symbol fast path incorrect' unless no_allocation.has_key?(:present)
raise 'integer/multi-key fast path incorrect' unless no_allocation.has_key?(1, :present)
puts "SA hash lookup: #{checks} legacy-equivalence cases, nil/false values, identity/custom keys and positive lookup without a full key-array allocation passed"
