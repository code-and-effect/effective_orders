module Admin
  class EffectiveItemNamesDatatable < Effective::Datatable
    bulk_actions do
      bulk_action('Archive selected', effective_orders.bulk_archive_admin_item_names_path)
      bulk_action('Unarchive selected', effective_orders.bulk_unarchive_admin_item_names_path)
    end

    filters do
      scope :unarchived, label: 'All'
      scope :archived
    end

    datatable do
      order :name

      bulk_actions_col

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
