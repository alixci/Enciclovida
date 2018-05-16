class Propiedad < ActiveRecord::Base

  establish_connection(:peces)
  self.table_name='propiedades'

  has_many :peces_propiedades, :class_name => 'PezPropiedad', :foreign_key => :propiedad_id
  has_many :peces, :through => :peces_propiedades, :source => :pez

  has_many :criterios, :class_name => 'Criterio', :foreign_key => :propiedad_id

  has_ancestry

  scope :grupos_conabio, -> { where(tipo_propiedad: 'Grupo CONABIO').order(:nombre_propiedad) }
  scope :zonas, -> { where(tipo_propiedad: 'zonas') }
  scope :tipo_capturas, -> { where(tipo_propiedad: 'Tipo de captura') }
  scope :tipo_vedas, -> { where(tipo_propiedad: 'Tipo de veda') }
  scope :procedencias, -> { where(tipo_propiedad: 'Procedencia') }
  scope :pesquerias, -> { select(:nombre_propiedad).where(tipo_propiedad: 'Pesquerías en vías de sustentabilidad ').distinct.order(:nombre_propiedad) }
  scope :cnp, -> { select(:nombre_propiedad).where(tipo_propiedad: ['zona pacifico', 'zona golfo y caribe']).distinct.order(:nombre_propiedad) }
  scope :nom, -> { where(tipo_propiedad: 'Norma Oficial Mexicana 059 SEMARNAT-2010') }
  scope :iucn, -> { where(tipo_propiedad: 'Lista roja IUCN 2016-3') }

end