# A [Thread]-backed computation that returns a result. The computation runs in
# its own thread, ensuring the current thread is not blocked. At any point, the
# task can be queried to see if the computation has completed. Once the task is
# finished, the result can be accessed at any point afterwards.
class Task
  # Create a new task that will run the computation given in the specified
  # block.
  def initialize
    @thread = Thread.new { Thread.current[:result] = yield }
  end

  # Check if the task has finished successfully. In this case, the result of
  # the task's computation can be retrieved.
  #
  # @see #result
  def is_finished?
    @thread.status == false
  end

  # Check if the task has completed unsuccessfuly. In this case, no result is
  # available, since an error occurred.
  def has_errored?
    @thread.status.nil?
  end

  # Retrieve the result of the task's computation. Only valid after the task
  # has successfully completed.
  #
  # @see #is_finished?
  # @see #has_errored?
  def result
    raise 'Task has errored out' if has_errored?
    raise 'Task has not completed' unless is_finished?
    @thread[:result]
  end
end
