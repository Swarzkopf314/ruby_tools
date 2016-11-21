# for Rails
# by Piotr Wojciechowski

module AdditionalFieldable

  ACCEPTABLE_FIELDS_TYPES = AdditionalField::FIELDS_TYPES

  extend ActiveSupport::Concern

  included do

    has_many :_additional_fields, as: :object, dependent: :destroy, class_name: "AdditionalField", autosave: true

    def _additional_field(name)
      _additional_fields.find{|af| af.name == name.to_s}
    end

    def [](key)
        ret = super
        if ret.nil? && key.to_s.in?(self.class.additional_fields_names)
          send(key)
        else
          ret
        end
    end

    def []=(key, value)
      begin
        super
      rescue ActiveModel::MissingAttributeError => e
        if key.to_s.in?(self.class.additional_fields_names)
          send("#{key}=", value)
        else
          raise e
        end
      end
    end

  end


  module ClassMethods

    def _additional_fields_types
      @_additional_fields_types ||= {}.with_indifferent_access
    end

    def additional_fields_names
      _additional_fields_types.keys
    end

    def additional_field(name, type, serializable: false, read_only: false)
      raise "zly typ pola: #{type}! dopuszczalne to: #{ACCEPTABLE_FIELDS_TYPES}" unless type.in?(ACCEPTABLE_FIELDS_TYPES)
      raise "serializable dopuszczalne tylko dla typow string i text" if serializable && !type.in?(%i(string text))

      _additional_fields_types[name] = type

      define_method("additional_field_#{name}") do
        _additional_field(name)
      end

      define_method(name) do
        value = _additional_field(name).try(type)
        value = YAML.load(value) if serializable && value
        value
      end

      unless read_only
        define_method("#{name}=") do |value|
          value = value.presence.try(:to_yaml) if serializable
          field = send("additional_field_#{name}") || _additional_fields.build(name: name)
          field.send("#{type}=", value)
        end
      end

    end 

    # _where_af(:accounting_id2, {string: 'abc'})
    # _where_af(:accounting_id2, 'string like "%abc"'})
    def _where_af(name, where_cond)
      where(id: _ids_where_af(name, where_cond))
    end

    def _ids_where_af(name, where_cond)
      AdditionalField.where(object_type: self.name).where(name: name).where(where_cond).pluck(:object_id)
    end

    
    # where_af(accounting_id2: 'abc')
    # where_af(:accounting_id2, 'like "%abc"')
    def where_af(*args)
      _where_af(*_generate_af_name_and_where_condition(args))
    end

    def ids_where_af(*args)
      _ids_where_af(*_generate_af_name_and_where_condition(args))
    end

    private

    def _generate_af_name_and_where_condition(args)
      if args.size == 2
        name, value = args
        type = _additional_fields_types[name]
        where_cond = "#{type} #{value}"
      elsif args.size == 1 && args[0].is_a?(Hash)
        name, value = args[0].first
        type = _additional_fields_types[name]
        where_cond = {type => value}
      else
        raise "nie obsluzona funkcjonalnosc"
      end
      raise "brak pola #{name}" unless _additional_fields_types.has_key?(name)
      return [name, where_cond]
    end

  end

end


class AdditionalField < ActiveRecord::Base
  default_scope proc{where({:account_id => Account.current_account.id})}

  belongs_to :object, :polymorphic => true
  belongs_to :account

  validates_uniqueness_of :name, :scope => [:account_id, :object_type, :object_id], :case_sensitive => false

  FIELDS_TYPES = %i(integer string text boolean date datetime decimal)

  after_save -> {destroy! if FIELDS_TYPES.all?{|type| send(type).blank?}}

end