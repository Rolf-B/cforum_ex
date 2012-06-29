class ThreadsController < ApplicationController
  SHOW_THREADLIST = "show_threadlist"
  SHOW_THREAD = "show_thread"
  SHOW_NEW_THREAD = "new_thread"

  def index
    if params[:t]
      thread = CForum::Thread.find_by_tid("t" + params[:t])

      if thread
        if params[:m] && message = thread.find_message(params[:m])
          return redirect_to message_path(thread, message)
        else
          return redirect_to thread_path(thread)
        end
      end
    end

    if ConfigManager.setting('use_archive')
      @threads = CForum::Thread.where(archived: false).order('message.created_at' => -1).all
    else
      @threads = CForum::Thread.order('message.created_at' => -1).limit(ConfigManager.setting('pagination') || 10)
    end

    notification_center.notify(SHOW_THREADLIST, @threads)
  end

  def show
    @id = make_id
    @thread = CForum::Thread.find_by_id(@id)

    notification_center.notify(SHOW_THREAD, @thread)
  end

  def edit
    @id = make_id
    @thread = CForum::Thread.find_by_id(@id)
  end

  def new
    @thread = CForum::Thread.new
    @thread.message = CForum::Message.new
    @thread.message.author = CForum::Author.new
    @categories = ConfigManager.setting('categories', [])

    notification_center.notify(SHOW_NEW_THREAD, @thread)
  end

  def create
    @thread = CForum::Thread.new(params[:c_forum_thread])

    respond_to do |format|
      if @thread.save
        format.html { redirect_to @thread, notice: 'Campaign was successfully created.' }
        format.json { render json: @thread, status: :created, location: @thread }
      else
        format.html { render action: "new" }
        format.json { render json: @thread.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
  end

  private

  def make_id
    '/' + params[:year] + '/' + params[:mon] + '/' + params[:day] + '/' + params[:tid]
  end
end

# eof
