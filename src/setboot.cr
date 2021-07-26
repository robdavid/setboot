# TODO: Write documentation for `Setboot`
require "option_parser"

module Setboot
  extend self
  VERSION = "0.1.0"

  # Define some custom exceptions

  class SetbootException < Exception
  end

  class DisplayedHelp < Exception
  end

  class BootManagerFail < SetbootException
    def initialize(stderr : String)
      super("Error running efibootmgr: #{stderr}")
    end
  end

  class BadOption < SetbootException
    def initialize(option)
      super("#{option} is not a valid option")
    end
  end

  class ExpectedSingleArg < SetbootException
    def initialize
      super("Expected single argument of (partial) boot entry name")
    end
  end

  class NoMatchingBootEntry < SetbootException
    def initialize()
      super("Cannot find matching and active boot entry")
    end
  end

  # Run efibootmgr, capturing output
  def efibootmgr(*args) : String
    stdout = IO::Memory.new
    stderr = IO::Memory.new
    status = Process.run("sudo",args: {"efibootmgr",*args},output: stdout, error: stderr)
    raise BootManagerFail.new(stderr.to_s) unless status.success?
    stdout.to_s
  end

  # An entry in the boot manager
  struct BootEntry
    getter number : UInt16
    getter active : Bool
    getter name : String

    def initialize(@number,@active,@name)
    end
  end

  # Captures data on the state of the boot manager
  class BootInfo
    getter current : UInt16 = 0
    getter nextent : UInt16? = nil
    getter order : Array(UInt16) = [] of UInt16
    getter entries : Hash(UInt16,BootEntry) = {} of UInt16 => BootEntry

    def initialize
      @re_current =  /BootCurrent:\s+([0-9A-F]+)/
      @re_order = /BootOrder:\s+([0-9A-F,]+)/
      @re_entry = /Boot([0-9A-F]+)([\* ])\s+(.*)$/
      @re_next = /BootNext:\s+([0-9A-F]+)/
    end

    # Process a single line from the output of efibootmgr
    def match_line!(line : String)
      case
      when match = @re_current.match(line)
        @current = match[1].to_u16(base:16)
        true
      when match = @re_order.match(line)
        match[1].split(",").each { |num| @order << num.to_u16(base:16) }
        true
      when match = @re_entry.match(line)
        bootnum = match[1].to_u16(base:16)
        @entries[bootnum] = BootEntry.new(bootnum, match[2]=="*", match[3])
        true
      when match = @re_next.match(line)
        @nextent = match[1].to_u16(base:16)
        true
      else
        false
      end
    end

    # Constructs an instance by consuming output for efibootmgr
    def self.from_bootmgr
      bi = BootInfo.new
      Setboot.efibootmgr.split("\n").each { |line| bi.match_line!(line) }
      bi
    end

    # Move the first matching and active entry to the start of the order 
    def promote!(substr : String) : UInt16?
      entry = @entries.find { |_,v| v.active && v.name.upcase.includes?(substr.upcase) }
      if entry.nil?
        nil
      else
        number = entry[0]
        @order.delete(number)
        @order.insert(0,number)
        number
      end
    end

    # Change the next boot entry to the first matching and active entry
    def bootnext!(substr : String) : UInt16?
      entry = @entries.find { |_,v| v.active && v.name.upcase.includes?(substr.upcase) }
      if entry.nil?
        nil
      else
        @nextent = entry[0]
      end
    end

    # Return a descriptive string for the boot order
    def bootlist : String
      @order.map { |num|
        entry = @entries[num]
        sprintf("%04X%c %s",num,entry.active ? '*' : ' ',entry.name)
      }.join("\n") + "\n"
    end

    # Set the current boot order in EFI
    def bootmgr_set_order
      args = {"-o",@order.map{|e| sprintf("%04X",e)}.join(",")}
      Setboot.efibootmgr(*args)
    end

    # Set the current next boot entry in EFI
    def bootmgr_set_next
      args = {"-n",sprintf("%04X",@nextent)}
      Setboot.efibootmgr(*args)
    end
  end

  begin
    nextboot = false
    showlist = false
    target_entry = nil
    prog = PROGRAM_NAME
    OptionParser.parse do |parser|
      parser.banner = "Usage: #{prog} [options] <boot_entry_name>"
      parser.on("-n", "--next", "Sets target for next reboot only") { nextboot = true }
      parser.on("-l", "--list", "Shows available boot entries, in boot order") { showlist = true }
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit
      end
      parser.invalid_option do |flag|
        STDERR.puts parser
        raise BadOption.new(flag)
      end
      parser.unknown_args do |args|
        target_entry = args[0] if args.size == 1
      end
    end
    bi = BootInfo.from_bootmgr
    if target_entry_nonnil = target_entry
      if nextboot   
        newnext = bi.bootnext!(target_entry_nonnil)
        raise NoMatchingBootEntry.new if newnext.nil?
        puts ("Setting entry #{sprintf("%04X",newnext)} \"#{bi.entries[newnext].name}\" as next boot target")
        bi.bootmgr_set_next
      else
        promoted = bi.promote!(target_entry_nonnil)
        raise NoMatchingBootEntry.new if promoted.nil?
        puts("Moving entry #{sprintf("%04X",promoted)} \"#{bi.entries[promoted].name}\" to head of the boot order")
        bi.bootmgr_set_order
      end
    elsif !showlist
      raise ExpectedSingleArg.new
    end
    puts(bi.bootlist) if showlist
  rescue DisplayedHelp
  rescue e : SetbootException
    STDERR.puts("#{prog}: #{e}")
    exit(1)
  end
end
