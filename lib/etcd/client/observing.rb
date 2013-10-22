module Etcd
  class Client

    # Sets up a continuous watch of a key or prefix.
    #
    # This method works like {#watch} (which is used behind the scenes), but
    # will re-watch the key or prefix after receiving a change notificiation.
    #
    # When re-watching the index of the previous change notification is used,
    # so no subsequent changes will be lost while a change is being processed.
    #
    # Unlike {#watch} this method as asynchronous. The watch handler runs in a
    # separate thread (currently a new thread is created for each invocation,
    # keep this in mind if you need to watch many different keys), and can be
    # cancelled by calling `#cancel` on the returned object.
    #
    # Because of implementation details the watch handler thread will not be
    # stopped directly when you call `#cancel`. The thread will be blocked until
    # the next change notification (which will be ignored). This will have very
    # little effect on performance since the thread will not be runnable. Unless
    # you're creating lots of observers it should not matter. If you want to
    # make sure you wait for the thread to stop you can call `#join` on the
    # returned object.
    #
    # @example Creating and cancelling an observer
    #   observer = client.observe('/foo') do |value|
    #     # do something on changes
    #   end
    #   # ...
    #   observer.cancel
    #
    # @return [#cancel, #join] an observer object which you can call cancel and
    #   join on
    def observe(prefix, &handler)
      ob = Observer.new(self, prefix, handler).tap(&:run)
      @observers[prefix] = ob
      ob
    end

    def observers_overview
      observers.map do |_, observer|
        observer.pp_status
      end
    end

    def refresh_observers_if_needed
      refresh_observers if observers.values.any?{|x| not x.status}
    end


    # Re-initiates watches after leader election
    def refresh_observers
      logger.debug("refresh_observers: enter")
      observers.each do |_, observer|
        observer.rerun unless observer.status
      end
    end

  end
end
