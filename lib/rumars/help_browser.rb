# frozen_string_literal: true

require 'rbconfig'
require 'open3'

module RuMARS
  # Context sensitive help browser. It uses the system web browser to display
  # online help pages.
  class HelpBrowser
    BASE_URL = 'https://scrapper.github.io/rumars/'

    def initialize(textwm)
      @textwm = textwm
    end

    def help_window
      context =
        case @textwm.active_window.name
        when 'Console Window'
          'commands'
        when 'Core Window'
          'redcode/opcodes'
        when 'Register Window'
          'redcode/address_modes'
        else
          'index'
        end

      launch_browser(BASE_URL + context)
    end

    private

    def launch_browser(url)
      case RbConfig::CONFIG['host_os']
      when /linux|bsd/
        system_command(['xdg-open', url])
      when /darwin/
        system_command(['open', url])
      when /mswin|mingw|cygwin/
        system_command(['start', "\"#{url}\""])
      end

      @textwm.update_windows
    end

    def system_command(argv)
      _, stdout, stderr, wait_thr = Open3.popen3(*argv)

      stdout.gets(nil)
      stdout.close
      stderr.gets(nil)
      stderr.close

      wait_thr.value
    end
  end
end
