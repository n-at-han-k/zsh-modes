#!/usr/bin/env ruby
# frozen_string_literal: true

# zsh-modes ruby backend — persistent evaluation server
# Reads lines from a FIFO, evaluates in a shared binding, writes results

require "json"

input_fifo  = ARGV[0]
output_fifo = ARGV[1]

binding_context = TOPLEVEL_BINDING.dup

loop do
  line = File.read(input_fifo).strip
  break if line == "__EXIT__"
  next  if line.empty?

  result = begin
    value = binding_context.eval(line, "(mode)", 1)
    { status: "ok", value: value.inspect }
  rescue SyntaxError => e
    { status: "error", value: "SyntaxError: #{e.message}" }
  rescue StandardError => e
    { status: "error", value: "#{e.class}: #{e.message}" }
  end

  File.write(output_fifo, JSON.generate(result))
rescue Errno::ENOENT
  sleep 0.05
  retry
rescue Interrupt
  break
end
