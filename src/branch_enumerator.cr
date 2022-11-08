module HM
  # This class helps with enumerating all possible variations of a type
  # definition which is useful during pattern matching since you need to
  # have possible branches for comparison.
  #
  # Some important information:
  # - an instance of branch enumerator should be only used once
  # - it needs all definitions for the types to be useful
  # - it doesn't check the defintions for soundness or even their exsistence
  #
  # The resulting type list can be used to match against branches of the pattern
  # matching, using the unifier module.
  class BranchEnumerator
    getter definitions : Array(Definition)

    def initialize(@definitions)
      @variable = 'a'.pred.to_s
    end

    def possibilities(definition : Definition) : Array(Checkable)
      case fields = definition.fields
      in Array(Variant)
        possibilities(fields)
      in Array(Field)
        possibilities(definition.name, fields)
      end
    end

    def possibilities(variants : Array(Variant)) : Array(Checkable)
      variants.map do |variant|
        # If a variant doesn't have any parameters we can just return a
        # type with it's name.
        if variant.items.size == 0
          Type.new(variant.name, [] of Field)
        else
          possibilities(variant.name, variant.items)
        end
      end.flatten
    end

    # Variables are replaced with an incrementing variable name.
    def possibilities(variable : Variable) : Array(Checkable)
      @variable =
        @variable.succ

      [Variable.new(@variable)] of Checkable
    end

    def possibilities(type : Type) : Array(Checkable)
      # We try to look up the definition of the type by name. If the definition
      # doesn't have any fields we can just return a type with it's name.
      if definition = definitions.find(&.name.==(type.name))
        if definition.fields.empty?
          [Type.new(definition.name, [] of Field)] of Checkable
        else
          possibilities(definition)
        end
      else
        # If there is no definition we just return the type itself.
        [type] of Checkable
      end
    end

    def possibilities(prefix : String, fields : Array(Field)) : Array(Checkable)
      parameters =
        fields.map { |field| possibilities(field.item) }

      compose(parameters).map do |item|
        named_fields =
          item.map do |field|
            # We need to keep the name of the field but since compose doesn't keep
            # it we need to get it with the index of the field.
            name =
              fields[item.index(field) || -1]?.try(&.name)

            Field.new(name, field)
          end

        Type.new(prefix, named_fields).as(Checkable)
      end
    end

    # This method composes the parts possibitilites into a flat list which
    # covers all posibilities.
    #
    #   compose([["a"], ["b"], ["c"]])
    #     ["a", "b", "c"]
    #
    #   compose([["a"], ["b", "c"], ["d"]])
    #     [
    #       ["a", "b", "d"],
    #       ["a", "c", "d"]
    #     ]
    #
    # Takes a value from first the first column and adds to it all the possibile
    # combination of values from the rest of the columns, recursively.
    private def compose(items : Array(Array(T))) : Array(Array(T)) forall T
      case items.size
      when 0
        [] of Array(T)
      when 1
        items[0].map { |item| [item] }
      else
        result =
          [] of Array(T)

        rest =
          compose(items[1...])

        items[0].each do |item|
          rest.each do |sub|
            result << [item] + sub
          end
        end

        result
      end
    end
  end
end
