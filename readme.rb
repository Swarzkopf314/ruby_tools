# why Presenter/Inventory etc. - different classes that wrap ActiveRecord
  
  # TODO - to jest bardzo dobry powod, zeby zaczac uzywac InvoicePresenter-a
  
  # delegator nie jest potrzebny jesli chcemy uzywac w widokach @invoice_presenter obok @invoice
  # class InvoicePresenter < SimpleDelegator
  #   def initialize(invoice)
  #     __setobj__(invoice)
  #     @invoice = invoice
  #   end
  #
  #   def accounting_doc?
  #     @invoice.accounting_doc? || @invoice.from_receipt?
  #   end
  # end

  # i potem w kontrolerze:
  # @invoice_presenter = InvoicePresenter.new(@invoice) - nie trzeba dziedziczyć po SimpleDelegator, ale trzeba wszedzie tego uzywac/przepisywac kod
  # lub wręcz:
  # @invoice = InvoicePresenter.new(@invoice) - dzialaloby z automatu w kazdym widoku, wymaga dziedziczenia po SimpleDelegatorze, ale jest potencjalnie niebezpieczne
