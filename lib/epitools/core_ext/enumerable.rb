

module Enumerable

  #
  # 'true' if the Enumerable has no elements
  #
  def blank?
    not any?
  end

  #
  # `.all` is more fun to type than `.to_a`
  #
  alias_method :all, :to_a

  #
  # `includes?` is gramatically correct.
  #
  alias_method :includes?,  :include?

  
  #  
  # Skip the first n elements and return an Enumerator for the rest, or pass them
  # in succession to the block, if given. This is like "drop", but returns an enumerator
  # instead of converting the whole thing to an array.
  #
  def skip(n)
    if block_given?
      each do |x|
        if n > 0
          n -= 1
        else
          yield x
        end
      end
    else
      enum_for :skip, n
    end
  end
  
  #
  # Split this enumerable into chunks, given some boundary condition. (Returns an array of arrays.)
  #
  # Options:
  #   :include_boundary => true  #=> include the element that you're splitting at in the results  
  #                                  (default: false)
  #   :after => true             #=> split after the matched element (only has an effect when used with :include_boundary)  
  #                                  (default: false)
  #   :once => flase             #=> only perform one split (default: false)
  #
  # Examples: 
  #   [1,2,3,4,5].split{ |e| e == 3 }                           
  #   #=> [ [1,2], [4,5] ]
  #
  #   [1,2,3,4,5].split(:include_boundary=>true) { |e| e == 3 } 
  #   #=> [ [1,2], [3,4,5] ] 
  #
  #   chapters = File.read("ebook.txt").split(/Chapter \d+/, :include_boundary=>true)
  #   #=> [ ["Chapter 1", ...], ["Chapter 2", ...], etc. ]
  #
  def split_at(matcher=nil, options={}, &block)
    # TODO: Ruby 1.9 returns Enumerators for everything now. Maybe use that?
    
    return self unless self.any?
    
    include_boundary = options[:include_boundary] || false

    if matcher.nil?
      boundary_test_proc = block
    else
      if matcher.is_a? String or matcher.is_a? Regexp
        boundary_test_proc = proc { |element| element[matcher] rescue nil }
      else
        boundary_test_proc = proc { |element| element == matcher }
        #raise "I don't know how to split with #{matcher}"
      end
    end

    chunks = []
    current_chunk = []
    
    splits = 0
    max_splits = options[:once] == true ? 1 : options[:max_splits]    

    each do |e|

      if boundary_test_proc.call(e) and (max_splits == nil or splits < max_splits)
        
        if current_chunk.empty? and not include_boundary 
          next # hit 2 boundaries in a row... just keep moving, people!
        end
        
        if options[:after]
          # split after boundary
          current_chunk << e        if include_boundary   # include the boundary, if necessary
          chunks << current_chunk                         # shift everything after the boundary into the resultset
          current_chunk = []                              # start a new result
        else
          # split before boundary
          chunks << current_chunk                         # shift before the boundary into the resultset
          current_chunk = []                              # start a new result
          current_chunk << e        if include_boundary   # include the boundary, if necessary
        end

        splits += 1
        
      else
        current_chunk << e
      end

    end
    
    chunks << current_chunk if current_chunk.any?

    chunks # resultset
  end

  #
  # Split the array into chunks, cutting between the matched element and the next element.
  #
  # Example:
  #   [1,2,3,4].split_after{|e| e == 3 } #=> [ [1,2,3], [4] ]
  #
  def split_after(matcher=nil, options={}, &block)
    options[:after]             ||= true
    options[:include_boundary]  ||= true
    split_at(matcher, options, &block)
  end

  #
  # Split the array into chunks, cutting between the matched element and the previous element.
  #
  # Example:
  #   [1,2,3,4].split_before{|e| e == 3 } #=> [ [1,2], [3,4] ]
  #
  def split_before(matcher=nil, options={}, &block)
    options[:include_boundary]  ||= true
    split_at(matcher, options, &block)
  end

  #
  # Sum the elements
  #  
  def sum
    if block_given?
      inject(0) { |total,elem| total + yield(elem) }    
    else
      inject(0) { |total,elem| total + elem }
    end
  end
  
  #
  # Average the elements
  #
  def average
    count = 0
    sum = inject(0) { |total,n| count += 1; total + n }
    sum / count.to_f
  end

  #
  # The same as "map", except that if an element is an Array or Enumerable, map is called
  # recursively on that element.
  #
  # Example:
  #   [ [1,2], [3,4] ].deep_map{|e| e ** 2 } #=> [ [1,4], [9,16] ] 
  #
  def deep_map(depth=nil, &block)
    map do |obj|

      case obj
      when Enumerable
        obj.deep_map(&block)
      else
        block.call(obj)
      end

    end
  end
  
  alias_method :recursive_map,    :deep_map
  alias_method :map_recursively,  :deep_map
  alias_method :map_recursive,    :deep_map 

  #
  # The same as "select", except that if an element is an Array or Enumerable, select is called
  # recursively on that element.
  #
  # Example:
  #   [ [1,2], [3,4] ].deep_map{|e| e ** 2 } #=> [ [1,4], [9,16] ] 
  #
  def deep_select(depth=nil, &block)
    select do |e|
      if (e.is_a? Array or e.is_a? Enumerable) and (depth && depth > 0)
        e.select(depth-1, &block)
      else
        block.call(e)
      end
    end
  end
  
  alias_method :recursive_select, :deep_select
  

  #
  # Identical to "reduce" in ruby1.9 (or foldl in haskell.)
  #
  # Example:
  #   array.foldl{|a,b| a + b } == array[1..-1].inject(array[0]){|a,b| a + b }
  #
  def foldl(methodname=nil, &block)
    result = nil

    raise "Error: pass a parameter OR a block, not both!" unless !!methodname ^ block_given?
      
    if methodname
      
      each_with_index do |e,i|
        if i == 0
          result = e 
          next
        end
        
        result = result.send(methodname, e)      
      end
      
    else
      
      each_with_index do |e,i|
        if i == 0
          result = e 
          next
        end
        
        result = block.call(result, e)      
      end
      
    end
    
    result
  end

  #
  # Returns the powerset of the Enumerable
  #
  # Example:
  #   [1,2].powerset #=> [[], [1], [2], [1, 2]]
  #
  def powerset
    # the bit pattern of the numbers from 0..2^(elements)-1 can be used to select the elements of the set...
    a = to_a
    (0...2**a.size).map do |bitmask|
      a.select.with_index{ |e, i| bitmask[i] == 1 }
    end
  end

  #
  # Does the opposite of #zip -- converts [ [:a, 1], [:b, 2] ] to [ [:a, :b], [1, 2] ]
  #  
  def unzip
    # TODO: make it work for arrays containing uneven-length contents
    to_a.transpose
  end
  
  #
  # Associative grouping; groups all elements who share something in common with each other.
  # You supply a block which takes two elements, and have it return true if they are "neighbours"
  # (eg: belong in the same group). 
  #
  # Example:
  #   [1,2,5,6].group_neighbours_by { |a,b| b-a <= 1 } #=> [ [1,2], [5,6] ]
  #
  # (Note: This is a very fast one-pass algorithm -- therefore, the groups must be pre-sorted.)
  #
  def group_neighbours_by(&block)
    result = []
    cluster = [first]
    each_cons(2) do |a,b|
      if yield(a,b)
        cluster << b
      else
        result << cluster
        cluster = [b]
      end
    end
    
    result << cluster if cluster.any?
    
    result    
  end
  alias_method :group_neighbors_by, :group_neighbours_by 
  

  #
  # Convert the array into a stable iterator (Iter) object.
  #
  def to_iter
    Iter.new(to_a)
  end
  alias_method :iter, :to_iter


end


