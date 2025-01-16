module Admin
  class EffectiveItemNamesDatatable < Effective::Datatable
    filters do
      scope :unarchived, label: 'All'
      scope :archived
    end

    datatable do
      order :name

      col :id, visible: false
      col :name
      col :archived, visible: false

      actions_col
    end

    collection do
      Effective::ItemName.all
    end
  end
end
