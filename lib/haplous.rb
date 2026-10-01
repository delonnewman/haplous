require 'date'

class DateRange
  include Enumerable
  include Comparable

  extend Forwardable
  def_delegator :range, :to_a

  attr_reader :first, :last

  def initialize(first, last)
    @first = first
    @last  = last
  end

  def range
    @first..@last
  end

  def each(&)
    return range.each unless block_given?

    range.each(&)
  end

  def <=>(other)
    return unless other.is_a?(self.class)

    first <=> other.first
  end
end

class ServiceYear < DateRange
  class << self
    def current
      from_date(Date.today)
    end

    def from_date(date)
      if date.month >= 9
        new(date.year, date.year + 1)
      else
        new(date.year - 1, date.year)
      end
    end

    def years
      first.year..last.year
    end

    def inspect
      "#<#{self.class} #{years}>"
    end
  end

  attr_reader :years

  def initialize(first, last)
    super(Date.new(first, 9, 1), Date.new(last, 8, 31))
    @years = first..last
  end

  def months
    first_month..last_month
  end

  def first_month
    Month.from_date(@first)
  end

  def last_month
    Month.from_date(@last)
  end
end

class Month < DateRange
  include Comparable

  NAMES = [
    nil,
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ].freeze

  class << self
    def current
      from_date(Date.today)
    end

    def from_date(date)
      new(date.year, date.month)
    end
  end

  attr_reader :year, :month

  def initialize(year, month)
    raise "invalid month #{month}" unless (1..12).include?(month)

    @year  = year
    @month = month

    last = (month == 12 ? Date.new(@year + 1, 1, 1) : Date.new(@year, @month + 1)).prev_day
    super(Date.new(@year, @month, 1), last)
  end

  def name
    NAMES[@month]
  end

  def to_s
    "#{name} #{@year}"
  end

  def inspect
    "#<#{self.class} \"#{name} #{@year}\">"
  end

  def prev
    self.class.new(@year - 1, 12) if @month == 1

    self.class.new(@month, @month - 1)
  end
  alias pred prev

  def next
    return self.class.new(@year + 1, 1) if @month == 12

    self.class.new(@year, @month + 1)
  end
  alias succ next

  def first_week
    Week.from_date(first)
  end

  def last_week
    Week.from_date(last)
  end

  def weeks
    first_week..last_week
  end
end

class Week < DateRange
  class << self
    def current
      from_date(Date.today)
    end

    def from_date(date)
      wday = date.wday
      new(date - wday, date + ((7 - wday) - 1))
    end
  end

  def prev
    self.class.new(@first - 7, @last - 7)
  end
  alias pred prev

  def next
    self.class.new(@first + 7, @last + 7)
  end
  alias succ next
end

class Persistent
end

class Schedule < Persistent
end

class Event < Persistent
end
