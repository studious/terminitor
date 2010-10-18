module Terminitor
  # This class parses the Termfile to fit the new Ruby Dsl Syntax
  class Dsl

    def initialize(path)
			file = File.read(path)
			@setups = []
			@setup = []
			@options = {}
			@windows = { 'default' => {}}
			@_context = @windows['default']
			@_level = 0
			instance_eval(file)
    end

    # Contains all commands that will be run prior to the usual 'workflow'
    # e.g bundle install, setup forks, etc ...
    # setup "bundle install", "brew update"
    # setup { run('bundle install') }
		# if setup is found inside a block the commands are added to the
		# tabs found in that block or lower
    def setup(*commands, &block)
			setup_tasks = @_level == 0 ? @setup : []
      if block_given?
       	@_context, @_old_context = setup_tasks, @_context
        instance_eval(&block)
        @_context = @_old_context
      else
        setup_tasks.concat(commands)
      end
			@setups.push(setup_tasks) if @_level > 0
    end

    # sets command context to be run inside a specific group
    # group('new window') { tab('ls','gitx') }
    def group(name = nil, &block)
      traverse(&block)
    end

    # sets command context to be run inside a specific window
    # window('new window') { tab('ls','gitx') }
    def window(name = nil, &block)
      window_tabs = @windows[name || "window#{@windows.keys.size}"] = {}
      @_context, @_old_context = window_tabs, @_context
      traverse(&block)
      @_context = @_old_context
    end

    # stores command in context
    # run 'brew update'
    def run(command)
      @_context << command
    end

    # sets command context to be run inside specific tab
    # tab('new tab') { run 'mate .' }
    # tab 'ls', 'gitx'
    def tab(name= nil, *commands, &block)
			tasks = @setups.flatten
      if block_given?
				tab_tasks = @_context[name || "tab#{@_context.keys.size}"] = tasks
        @_context, @_old_context = tab_tasks, @_context
        traverse(&block)
        @_context = @_old_context
      else
				tab_tasks = @_context["tab#{@_context.keys.size}"] = tasks
        tab_tasks.concat([name] + commands)
      end
    end

    # Returns yaml file as Terminitor formmatted hash
    def to_hash
      { :setup => @setup, :options => @options, :windows => @windows }
    end

		# Sets up our own working dir
		def options(commands)
			@options.merge! commands
		end

    private

		# traverse depth to indicate if we are in a window or group etc
		# remove the setup for that block once done
		def traverse(&block)
			@_level += 1
			instance_eval(&block)
			@setups.pop
			@_level -= 1
		end
		
    #
    # in_context @setup, commands, &block
    # in_context @tabs["name"], commands, &block
    def in_context(tasks_instance,*commands, &block)
      if block_given?
        @_context, @_old_context = instance_variable_get(name), @_context
        instance_eval(&block)
        @_context = @_old_context
      else
        @setup << commands
      end
    end


  end
end
