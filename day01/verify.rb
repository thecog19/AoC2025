counter = 50
zero_passes = 0

File.readlines("inputs/day1_input.txt").each do |line|
  line = line.strip
  next if line.empty?

  direction = line[0]
  amount = line[1..].to_i
  started_at = counter

  if direction == 'L'
    counter -= amount

    first_wrap = true
    while counter < 0
      # Skip first wrap if we started at 0 (we're leaving, not passing through)
      if first_wrap && started_at == 0
        first_wrap = false
      else
        zero_passes += 1
      end
      counter += 100
    end

    # Always count landing on 0 for L
    if counter == 0
      zero_passes += 1
    end
  else
    # R direction
    counter += amount

    wrapped = false
    while counter > 99
      zero_passes += 1
      counter -= 100
      wrapped = true
    end

    # For R: only count landing on 0 if we didn't wrap
    # (if we wrapped and landed on 0, the wrap already counted it)
    if counter == 0 && !wrapped
      zero_passes += 1
    end
  end
end

puts "Final counter: #{counter}"
puts "Zero passes: #{zero_passes}"
