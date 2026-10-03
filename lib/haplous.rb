require 'date'
require 'bundler/setup'

require 'time-of-day'
require 'extralite'

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

class Year < DateRange
  class << self
    def current(kind = :calendar)
      public_send(kind, Date.today.year)
    end

    def calendar(year)
      new(Date.new(year, 1, 1), Date.new(year, 12, 31))
    end

    def service(year)
      new(Date.new(year, 9, 1), Date.new(year + 1, 8, 31))
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
    super
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

    last =
      if month == 12
        Date.new(@year + 1, 1, 1)
      else
        Date.new(@year, @month + 1, 1)
      end.prev_day

    super(Date.new(@year, @month, 1), last)
  end

  def name
    Date::MONTHNAMES[@month]
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

class Duration
  include Comparable

  extend Forwardable
  def_delegators :@seconds, :to_i, :to_f, :to_r

  class << self
    def seconds(seconds)
      new(seconds)
    end

    def minutes(minutes)
      new(minutes * 60)
    end

    def hours(hours)
      new(hours * 3600)
    end
  end

  attr_reader :seconds

  def initialize(seconds)
    @seconds = seconds
    freeze
  end

  alias in_seconds seconds

  def in_minutes
    @seconds / 60.0
  end

  def in_hours
    @seconds / 3600.0
  end

  def parts
    hours = in_hours
    hour  = hours.to_i
    mins  = (hours - hour) * 60
    min   = mins.to_i
    sec   = ((mins - min) * 60).round

    [hour, min, sec]
  end

  def hour
    parts => [hour]
    hour
  end

  def min
    parts => [_, min]
    min
  end

  def sec
    parts => [_, _, sec]
    sec
  end

  def to_s(include_hours: true)
    parts => [hour, min, sec]
    sign = sec.negative? ? '-' : ''

    unless include_hours || hour.positive?
      format '%<sign>s%<min>02d:%<sec>02d', sign:, min: min.abs, sec: sec.abs
    end

    format '%<sign>s%<hour>02d:%<min>02d:%<sec>02d',
           sign:, hour: hour.abs, min: min.abs, sec: sec.abs
  end
  alias inspect to_s

  def hash
    [self.class.name, @amount].hash
  end

  def eql?(other)
    return unless other.is_a?(self.class)

    hash == other.hash
  end

  def +(other)
    case other
    when Duration
      Duration.new(other.seconds + @seconds)
    else
      Duration.new(other + @seconds)
    end
  end

  def -@
    Duration.new(-@seconds)
  end

  def -(other)
    case other
    when Duration
      Duration.new(@seconds - other.seconds)
    else
      Duration.new(@seconds - other)
    end
  end

  def *(other)
    case other
    when Duration
      Duration.new(@seconds * other.seconds)
    else
      Duration.new(@seconds * other)
    end
  end

  def /(other)
    case other
    when Duration
      Duration.new(@seconds / other.seconds)
    else
      Duration.new(@seconds / other)
    end
  end

  def <=>(other)
    return unless other.is_a?(self.class)

    @seconds <=> other.seconds
  end
end

EMPTY_ARRAY = [].freeze

class Enum
  def self.define(*members)
    enum = Class.new(Enum)
    member_class = Class.new(enum) do
      attr_reader :name, :value
      def initialize(name, value)
        @name  = name
        @value = value
        freeze
      end

      def inspect
        "#<enum #{self.class.superclass} #{@name}=#{@value}>"
      end
      alias to_s inspect
    end

    enum.instance_eval do
      def members_by_name
        @members_by_name ||= {}
      end

      def members_by_value
        @members_by_value ||= {}
      end

      members.each_with_index do |name, value|
        member = member_class.new(name, value)
        members_by_name[name] = member
        members_by_value[value] = member
      end

      def new(...)
        raise NoMethodError
      end

      def members
        members_by_name.keys
      end

      def member(name)
        members_by_name.fetch(name)
      end

      members.each do |name|
        define_singleton_method name do
          members_by_name[name]
        end
      end
    end

    enum
  end
end

module Period
  def duration
    Duration.new(ended_at - started_at)
  end
end

Schedule = Data.define(:name, :description, :slots, :goal_id, :starts_at, :ends_at)
class Schedule
  include Period

  def initialize(description: nil, slots: EMPTY_ARRAY, **attributes)
    super(description:, slots:, **attributes)
  end
end

Periodicity = Enum.define(:daily, :weekly, :monthly, :yearly)

Slot = Data.define(:weekday, :schedule_id, :starts_at, :ends_at, :periodicity)
class Slot
  include Period

  def initialize(periodicity: Periodicity.weekly, **attributes)
    super(periodicity:, **attributes)
  end
end

Event = Data.define(:goal_id, :starts_at, :ends_at)
class Event
  include Period
end

Goal = Data.define(:id, :name, :amount, :unit, :periodicity)
class Goal
  def initialize(id: nil, periodicity: Periodicity.weekly, **attributes)
    super(periodicity:, id:, **attributes)
  end
end

class Store
  attr_reader :db

  def initialize(db)
    @db = db
  end
end

class SchedulesStore < Store
  def create(schedule)
    db.execute <<~SQL, schedule
      insert into schedules (name, description, goal_id, starts_at, ends_at)
        values ($name, $description, $goal_id, $starts_at, $ends_at)
    SQL
  end

  def by_id(id)
    db.query_single <<~SQL, id:
      select * from schedules where id = $id
    SQL
  end
end

class EventsStore < Store
end

class GoalsStore < Store
  def create(goal)
    db.execute <<~SQL, goal
      insert into goals (name, amount, unit, periodicity)
        values ($name, $amount, $unit, $periodicity)
    SQL
  end
end

class Haplous
  attr_reader :db, :schedules, :goals, :events

  def initialize(dbfile, &)
    @db        = Extralite::Database.new(root_path.join(dbfile).to_s)
    @schedules = SchedulesStore.new(@db)
    @goals     = GoalsStore.new(@db)
    @events    = EventsStore.new(@db)
    instance_exec(&) if block_given?
  end

  def root_path
    Pathname.new(__dir__).join('..').realpath
  end
end

App = Haplous.new('db/haplous.sqlite3') do
  db.execute <<~SQL
    create table if not exists goals (
      id          integer primary key autoincrement,
      name        text    not null unique,
      amount      integer not null,
      unit        text    not null,
      periodicity integer not null -- enum
    );

    create table if not exists schedules (
      id          integer primary key autoincrement,
      name        text    not null unique,
      description text
      starts_at   datetime not null,
      ends_at     datetime not null,
      goal_id     integer  not null,

      foreign key (goal_id) references goals (id) on delete cascade
    );

    create table if not exists slots (
      id          integer primary key autoincrement,
      periodicity integer not null, -- enum
      weekday     integer, -- for weekly schedules
      monthday    integer, -- for montly schedules
      yearmonth   integer, -- for yearly schedules
      yeardate    integer, -- for yearly schedules
      starts_at   integer not null, -- time of day
      ends_at     integer not null, -- time of day
      schedule_id integer not null,

      foreign key (schedule_id) references schedules (id) on delete cascade
    );

    create table if not exists events (
      id         integer primary key autoincrement,
      starts_at  datetime not null,
      ends_at    datetime not null,
      goal_id    integer  not null,

      foreign key (goal_id) references goals (id) on delete cascade
    );
  SQL
end
