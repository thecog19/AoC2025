#!/usr/bin/env ruby

def invalid?(n)
  s = n.to_s
  len = s.length

  (1..len/2).each do |pattern_len|
    next unless len % pattern_len == 0

    pattern = s[0, pattern_len]
    reps = len / pattern_len

    return true if pattern * reps == s
  end

  false
end

sum = 0

File.read("inputs/day2_input.txt").split(",").each do |range|
  a, b = range.split("-").map(&:to_i)
  (a..b).each { |n| sum += n if invalid?(n) }
end

puts sum
