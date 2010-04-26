class Role < ActiveRecord::Base
  CURRENT = ["current_date between roles.start_date and roles.end_date"].freeze

  belongs_to :person
  belongs_to :chamber

  # One of state or district is always available, see #place
  belongs_to :state
  belongs_to :district
  
  # There is not always an associated session. It's there for Fifty States data but not GovTrack.
  # And anyway, people don't get elected to sessions--they get elected to chambers.
  belongs_to :session
  
  before_save :assure_dates_in_order

  validates_numericality_of :senate_class, :only_integer => true, :allow_blank => true, :in => [1...3]

  validates_presence_of :state, :if => "district.nil?"
  validates_presence_of :district, :if => "state.nil?"

  named_scope :current, :conditions => Role::CURRENT


  def place
    # for a given class, returns the appropriate symbol
    # to pass to the ActiveRecord method reflect_on_association
    def reflection_symbol(klass)
      klass.to_s.split("::").last.underscore.to_sym
    end

    # for all subclasses of the given base class, returns a
    # list of defined associations within the current class
    def association_methods(mti_base_class)
      Object.subclasses_of(mti_base_class).collect{|p|
        assoc = self.class.reflect_on_association(reflection_symbol(p))
        assoc ? assoc.name : nil
      }.compact
    end

    # invoke each association method and return the first
    # that is not null
    association_methods(Place).collect{|a|
      self.send a
    }.inject do |a, b|
      a || b
    end
  end

  def place=(p)
    def reflection_symbol(klass)
      klass.to_s.split("::").last.underscore.to_sym
    end

    def reflection_assignment_method(klass)
      Role.reflect_on_association(reflection_symbol(klass.class)).name.to_s + "="
    end

    self.send reflection_assignment_method(p.class), p
  end

  protected

  def assure_dates_in_order
    if !self.end_date.blank?
      errors.add(:end_date, "can't come before start date") unless (self.start_date < self.end_date)
    end
  end
end