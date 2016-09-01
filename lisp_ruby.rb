#!/usr/bin/ruby

RLSP_VERSION = "1.4.2"

class Lambda
  attr_accessor :args, :body
  def initialize(args=[],body="")
    @args = (args.class == Array) ? args : [args]
    @body = body
  end
end

def strip_array arr
  while arr.length == 1 && arr[0].class == Array
    arr = arr[0]
  end
  arr
end

def strip_whitespace(str)
  str.split("\n").map { |l| (l[0].chr == ';') ? "\n" : l unless l[0] == nil }.join("\n").gsub(/[\n\t\r]+/,' ').gsub(/\s{2,}/,' ').strip
end

def split_to_lines(str)
  ret   = []
  level = 0
  for i in 0...str.length
    cur = str[i].chr
    if cur == '(' then
      ret.push String.new if level == 0
      level += 1
    elsif cur == ')' then
      ret[-1] << ")" if level == 1
      level -= 1
    end
    ret[-1] << cur if level > 0
  end
  ret
end

def parse(str)
  return str if str.class != String
  str = str.sub(/^\(/,'').sub(/\)$/,'')
  return $1 if str =~ /^"([^"]+)"$/
  return str.to_i if str =~ /^(\-|)\d+$/
  return str.to_f if str =~ /^(\-|)\d+\.\d+$/
  return $1 == 't' if str =~ /^(t|f)$/
  return str.intern if !str.index(' ') && !str.index('(') && !str.empty?
  splstr = str.split(' ')
  splstr.each_index do |i|
    if splstr[i] =~ /^"[^"]+$/ then
      a = splstr[i+1]
      while a !~ /^[^"]+"$/
        splstr[i] += ' ' + a
        splstr.delete(a)
        a = splstr[i+1]
      end
      splstr[i] += ' ' + a
      splstr.delete(a)
    elsif splstr[i] =~ /^\([^)]+$/ then
      stack = splstr[i].scan('(').length - splstr[i].scan(')').length
      while stack > 0
        a = splstr[i+1]
        splstr[i] += ' ' + a
        stack += a.scan('(').length - a.scan(')').length
        splstr.delete_at(i+1)
      end
    end
  end
  splstr.map { |item| parse item }
end

def lisp_eval(exp, env)
  return exp if ![Array,Symbol].index exp.class
  if exp.class == Symbol
    return lisp_eval(env[exp],env) if env.has_key? exp
    return exp
  end
  return exp if exp.length == 0
  exp = strip_array exp
  fn = exp[0]
  args = exp[1...exp.length]
  return special lisp_eval(fn, env), args, env if is_special? fn
  lisp_apply lisp_eval(fn, env), eval_list(args, env), env
end

def lisp_apply(function, args, env)
  return primitive(function, args, env) if is_primitive? function
  raise "'%s' is not a function" % function unless function.class == Lambda
  a = eval_list(args,env)
  for i in 0...args.length
    env[function.args[i]] = a[i]
  end
  lisp_eval(function.body,env)
end

def eval_list(items, env)
  return lisp_eval(items,env) if items.class != Array
  items.map { |x| lisp_eval(x, env) }
end

def is_primitive? fn
  [:print, :last, :first, :rest, :list, :read, :eval, :+, :-, :/, :*, :'=', :atom?, :'!=', :'<', :do].index fn
end

def primitive(name, args, env)
  args = eval_list(args,env)
  case name
    when :print
      puts args.join(' ')
    when :first
      args = strip_array args
      args[0]
    when :last
      args = strip_array args
      args[-1]
    when :rest
      args = strip_array args
      args[1...args.length]
    when :list
      args
    when :read
      gets
    when :eval
      args = strip_array args
      lisp_eval(parse(strip_whitespace(args[0])),env)
    when :atom?
      args[0].class != Array
    when :+
      args = strip_array args
      args[0] + args[1]
    when :-
      args = strip_array args
      args[0] - args[1]
    when :/
      args = strip_array args
      args[0] / args[1].to_f
    when :*
      args = strip_array args
      args[0] * args[1]
    when :'='
      args[0] == args[1]
    when :'!='
      args[0] != args[1]
    when :'<'
      args[0] < args[1]
    when :do
      args[-1]
  end
end

def is_special? fn
  [:if,:while,:def,:fn,:defn].index(fn)
end

def special(name, args, env)
  case name
    when :if
      if lisp_eval(args[0],env) then
        lisp_eval(args[1],env)
      elsif args.length == 3
        lisp_eval(args[2],env)
      end
    when :while
      while lisp_eval(args[0],env)
        lisp_eval(args[1],env)
      end
    when :def
      env[lisp_eval(args[0],env)] = args[1]
      nil
    when :fn
      Lambda.new(lisp_eval(args[0],env), args[1])
    when :defn
      env[lisp_eval(args[0],env)] = Lambda.new(lisp_eval(args[1],env),args[2])
  end
end

e = {}

puts "rlsp version %s" % RLSP_VERSION
if ARGV.length > 0 then
  program = IO.readlines(ARGV.shift).join("\n")
  split_to_lines(strip_whitespace program).each { |l| lisp_eval parse(l), e }
else
  while true
    print "rlsp> "
    line = gets
    break if line == nil
    line.chomp!
    while line.scan('(').length > line.scan(')').length
      line += gets.chomp
    end
    begin
      split_to_lines(strip_whitespace(line)).each { |l| puts lisp_eval(parse(l), e) }
    rescue Exception => er
      puts "\t"+er.backtrace[0]+': '+er.message
    end
  end
end