class Admin::DocumentsController < Admin::BaseController
  def index
    @documents = Document.order(:title, :id)
  end

  def show
    @document = Document.find(params[:id])
  end

  def new
    @document = Document.new
  end

  def create
    @document = Document.new(document_params)
    if @document.save
      redirect_to admin_document_path(@document), notice: "Document created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @document = Document.find(params[:id])
  end

  def update
    @document = Document.find(params[:id])
    if @document.update(document_params)
      redirect_to admin_document_path(@document), notice: "Document updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Document.find(params[:id]).destroy!
    redirect_to admin_documents_path, notice: "Document deleted.", status: :see_other
  end

  private
    def document_params
      params.expect(document: [ :title, :body ])
    end
end
