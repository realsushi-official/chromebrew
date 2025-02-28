require 'English'
require_relative 'const'
require_relative 'color'
require_relative 'package_helpers'
require_relative 'selector'

class Package
  property :description, :homepage, :version, :license, :compatibility,
           :binary_url, :binary_sha256, :source_url, :source_sha256,
           :git_branch, :git_hashtag

  boolean_property = %i[conflicts_ok git_fetchtags gnome is_fake is_musl
                        is_static no_compile_needed no_compress no_env_options
                        no_fhs no_patchelf no_shrink no_strip no_zstd patchelf
                        git_clone_deep no_git_submodules]

  create_placeholder :preflight,   # Function for checks to see if install should occur.
                     :patch,       # Function to perform patch operations prior to build from source.
                     :prebuild,    # Function to perform pre-build operations prior to build from source.
                     :build,       # Function to perform build from source.
                     :postbuild,   # Function to perform post-build for both source build and binary distribution.
                     :check,       # Function to perform check from source build. (executes only during `crew build`)
                     :preinstall,  # Function to perform pre-install operations prior to install.
                     :install,     # Function to perform install from source build.
                     :postinstall, # Function to perform post-install for both source build and binary distribution.
                     :remove       # Function to perform after package removal.

  class << self
    attr_accessor :name, :cached_build, :in_build, :build_from_source,
                  :in_upgrade
    # Via https://stackoverflow.com/questions/7849521/set-attribute-dynamically-of-ruby-object/39063481#39063481
    def set_property(name, value)
      prop_name = "@#{name}".to_sym # you need the property name, prefixed with a '@', as a symbol
      instance_variable_set(prop_name, value)
    end
  end

  def self.load_package(pkgFile, pkgName = File.basename(pkgFile, '.rb'))
    # self.load_package: load a package under 'Package' class scope
    #
    className = pkgName.capitalize

    # read and eval package script under 'Package' class
    class_eval(File.read(pkgFile, encoding: Encoding::UTF_8), pkgFile) unless const_defined?("Package::#{className}")

    pkgObj = const_get(className)
    pkgObj.name = pkgName

    return pkgObj
  end

  def self.dependencies
    # We need instance variable in derived class, so not define it here,
    # base class.  Instead of define it, we initialize it in a function
    # called from derived classees.
    @dependencies ||= {}
  end

  def self.get_deps_list(pkgName = name, hash: false, include_build_deps: 'auto', include_self: false,
                         pkgTags: [], highlight_build_deps: true, exclude_buildessential: false, top_level: true)
    # get_deps_list: get dependencies list of pkgName (current package by default)
    #
    #                pkgName: package to check dependencies, current package by default
    #                   hash: return result in nested hash, used by `print_deps_tree` (`bin/crew`)
    #
    #     include_build_deps: if set to true, force all build dependencies to be returned.
    #                         if set to false, all build dependencies will not be returned
    #                         if set to "auto" (default), return build dependencies if pre-built binaries not available
    #
    #           include_self: include #{pkgName} itself in returned result, only used in recursive calls (see `expandedDeps` below)
    #   highlight_build_deps: include corresponding symbols in return value, you can convert it to actual ascii color codes later
    # exclude_buildessential: do not insert `buildessential` dependency automatically
    #
    #              top_level: if set to true, return satisfied dependencies
    #                         (dependencies that might be a sub-dependency of a dependency that checked before),
    #                         always set to false if this function is called in recursive loop (see `expandedDeps` below)
    #
    @checked_list ||= {} # create @checked_list placeholder if not exist

    # add current package to @checked_list for preventing extra checks
    @checked_list.merge!({ pkgName => pkgTags })

    pkgObj = load_package("#{CREW_PACKAGES_PATH}/#{pkgName}.rb")
    is_source = pkgObj.is_source?(ARCH.to_sym) or pkgObj.build_from_source
    deps = pkgObj.dependencies

    # append buildessential to deps if building from source is needed/specified
    if ((include_build_deps == true) || ((include_build_deps == 'auto') && is_source)) && \
       !pkgObj.no_compile_needed? && \
       !exclude_buildessential && \
       !@checked_list.keys.include?('buildessential')

      deps = { 'buildessential' => [:build] }.merge(deps)
    end

    # parse dependencies recursively
    expandedDeps = deps.uniq.map do |dep, depTags|
      # check build dependencies only if building from source is needed/specified
      next unless (include_build_deps == true) || \
                  ((include_build_deps == 'auto') && is_source) || \
                  !depTags.include?(:build)

      # overwrite tags if parent dependency is a build dependency
      # (for build dependencies highlighting)
      tags = pkgTags.include?(:build) ? pkgTags : depTags

      if @checked_list.keys.none?(dep)
        # check dependency by calling this function recursively
        next send(__method__, dep,
                  hash: hash,
               pkgTags: tags,
    include_build_deps: include_build_deps,
  highlight_build_deps: highlight_build_deps,
exclude_buildessential: exclude_buildessential,
          include_self: true,
             top_level: false)

      elsif hash && top_level
        # will be dropped here if current dependency is already checked and #{top_level} is set to true
        #
        # the '+' symbol tell `print_deps_tree` (`bin/crew`) to color this package as "satisfied dependency"
        # the '*' symbol tell `print_deps_tree` (`bin/crew`) to color this package as "build dependency"
        if highlight_build_deps && tags.include?(:build)
          next { "+*#{dep}*+" => [] }
        elsif highlight_build_deps
          next { "+#{dep}+" => [] }
        else
          next { dep => [] }
        end
      end
    end.compact

    if hash
      # the '*' symbol tell `print_deps_tree` (`bin/crew`) to color this package as "build dependency"
      if highlight_build_deps && pkgTags.include?(:build)
        return { "*#{pkgName}*" => expandedDeps }
      else
        return { pkgName => expandedDeps }
      end
    elsif include_self
      # return pkgName itself if this function is called as a recursive loop (see `expandedDeps`)
      return [expandedDeps, pkgName].flatten
    else
      # if this function is called outside of this function, return parsed dependencies only
      return expandedDeps.flatten
    end
  end

  boolean_property.each do |prop|
    self.class.__send__(:attr_reader, prop.to_s)
    class_eval <<~EOT, __FILE__, __LINE__ + 1
      def self.#{prop} (#{prop} = nil)
        @#{prop} = true if #{prop}
        !!@#{prop}
      end
    EOT
    instance_eval <<~EOY, __FILE__, __LINE__ + 1
      def self.#{prop}
        @#{prop} = true
      end
    EOY
    # Adds the symbol? method
    define_singleton_method("#{prop}?") do
      @prop = instance_variable_get("@#{prop}")
      !!@prop
    end
  end

  def self.compatible?
    if @compatibility
      return (@compatibility.casecmp?('all') || @compatibility.include?(ARCH))
    else
      warn "#{name}: Missing `compatibility` field.".lightred
      return false
    end
  end

  def self.depends_on(dependency = nil)
    @dependencies ||= {}
    if dependency
      # add element in "[ name, [ tag1, tag2, ... ] ]" format
      if dependency.is_a?(Hash)
        if dependency.first[1].is_a?(Array)
          # parse "depends_on name => [ tag1, tag2 ]"
          @dependencies.store(dependency.first[0], dependency.first[1])
        else
          # parse "depends_on name => tag"
          @dependencies.store(dependency.first[0], [dependency.first[1]])
        end
      else
        # parse "depends_on name"
        @dependencies.store(dependency, [])
      end
    end
    @dependencies
  end

  def self.get_url(architecture)
    if !@build_from_source && @binary_url && @binary_url.key?(architecture)
      return @binary_url[architecture]
    elsif @source_url.respond_to?(:has_key?)
      return @source_url.key?(architecture) ? @source_url[architecture] : nil
    else
      return @source_url
    end
  end

  def self.get_binary_url(architecture)
    return @binary_url.key?(architecture) ? @binary_url[architecture] : nil
  end

  def self.get_source_url(architecture)
    return @source_url.key?(architecture) ? @source_url[architecture] : nil
  end

  def self.get_sha256(architecture)
    if !@build_from_source && @binary_sha256 && @binary_sha256.key?(architecture)
      return @binary_sha256[architecture]
    elsif @source_sha256.respond_to?(:has_key?)
      return @source_sha256.key?(architecture) ? @source_sha256[architecture] : nil
    else
      return @source_sha256
    end
  end

  def self.get_extract_dir
    "#{name}.#{Time.now.utc.strftime('%Y%m%d%H%M%S')}.dir"
  end

  def self.is_binary?(architecture)
    if !@build_from_source && @binary_url && @binary_url.key?(architecture)
      return true
    else
      return false
    end
  end

  def self.is_source?(architecture)
    if is_binary?(architecture) || is_fake?
      return false
    else
      return true
    end
  end

  def self.system(*args, **opt_args)
    @crew_env_options_hash = if no_env_options?
                               { 'CREW_DISABLE_ENV_OPTIONS' => '1' }
                             else
                               CREW_ENV_OPTIONS_HASH
                             end

    # add "-j#" argument to "make" at compile-time, if necessary

    # Order of precedence to assign the number of processors:
    # 1. The value of '-j#' from the package make argument
    # 2. The value of ENV["CREW_NPROC"]
    # 3. The value of `nproc`.strip
    # See lib/const.rb for more details

    # add exception option to opt_args
    opt_args.merge!(exception: true) unless opt_args.key?(:exception)

    # extract env hash
    if args[0].is_a?(Hash)
      env = @crew_env_options_hash.merge(args[0])
      args.delete_at(0) # remove env hash from args array
    else
      env = @crew_env_options_hash
    end

    # after removing the env hash, all remaining args must be command args
    cmd_args = args

    # add -j arg to build commands
    if args.size == 1
      # involve a shell if the command is passed in one single string
      cmd_args = ['bash', '-c', cmd_args[0].sub(/^(make)\b/, "\\1 -j#{CREW_NPROC}")]
    elsif cmd_args[0] == 'make'
      cmd_args.insert(1, "-j#{CREW_NPROC}")
    end

    begin
      Kernel.system(env, *cmd_args, **opt_args)
    rescue StandardError => e
      # print failed line number and error message
      puts "#{e.backtrace[1]}: #{e.message}".orange
      raise InstallError, "`#{env.map { |k, v| "#{k}=\"#{v}\"" }.join(' ')} #{cmd_args.join(' ')}` exited with #{$CHILD_STATUS.exitstatus}".lightred
    end
  end
end
