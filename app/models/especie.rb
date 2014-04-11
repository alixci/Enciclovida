class Especie < ActiveRecord::Base

  self.table_name='especies'

  belongs_to :categoria_taxonomica
  has_many :especies_regiones, :class_name => 'EspecieRegion', :foreign_key => 'especie_id', :dependent => :destroy
  has_many :especies_catalogos, :class_name => 'EspecieCatalogo', :dependent => :destroy
  has_many :nombres_regiones, :class_name => 'NombreRegion', :dependent => :destroy
  has_many :nombres_regiones_bibliografias, :class_name => 'NombreRegionBibliografia', :dependent => :destroy
  has_many :especies_estatuses, :class_name => 'EspecieEstatus', :foreign_key => :especie_id1, :dependent => :destroy
  has_ancestry :ancestry_column => :ancestry_acendente_directo
  fuzzily_searchable :nombre_cientifico, :class_name => 'Trigram'
  accepts_nested_attributes_for :especies_catalogos, :reject_if => :all_blank, :allow_destroy => true
  accepts_nested_attributes_for :especies_regiones, :reject_if => :all_blank, :allow_destroy => true
  accepts_nested_attributes_for :nombres_regiones, :reject_if => :all_blank, :allow_destroy => true
  accepts_nested_attributes_for :nombres_regiones_bibliografias, :reject_if => :all_blank, :allow_destroy => true

  scope :caso_insensitivo, ->(columna, valor) { where("lower_unaccent(#{columna}) LIKE lower_unaccent('%#{valor}%')") }
  scope :caso_empieza_con, ->(columna, valor) { where("lower_unaccent(#{columna}) LIKE lower_unaccent('#{valor}%')") }
  scope :caso_sensitivo, ->(columna, valor) { where("#{columna}='#{valor}'") }
  scope :caso_termina_con, ->(columna, valor) { where("lower_unaccent(#{columna}) LIKE lower_unaccent('%#{valor}')") }
  scope :caso_fecha, ->(columna, valor) { where("CAST(#{columna} AS TEXT) LIKE '%#{valor}%'") }
  scope :caso_ids, ->(columna, valor) { where(columna => valor) }
  scope :caso_rango_valores, ->(columna, rangos) { where("#{columna} IN (#{rangos})") }
  scope :caso_estatus, ->(status) { where(:estatus => status.to_i) }
  scope :caso_nombre_comun, -> { joins(:nombres_regiones => [:nombre_comun]) }
  scope :caso_region, -> { joins(:especies_regiones => [:region]) }
  scope :caso_tipo_distribucion, -> { joins(:especies_regiones => [:tipo_distribucion]) }
  scope :caso_nombre_bibliografia, -> { joins(:nombres_regiones_bibliografias => [:bibliografia]) }
  scope :caso_especies_catalogos, -> { joins(:especies_catalogos => [:catalogo]) }
  scope :ordenar, ->(columna, orden) { order("#{columna} #{orden}") }
  scope :caso_categoria_taxonomica, -> { joins(:categoria_taxonomica) }
  scope :datos, -> { joins('LEFT JOIN especies_regiones ON especies.id=especies_regiones.especie_id').joins('LEFT JOIN categoria_taxonomica')}

  before_save :ponNombreCientifico

  WillPaginate.per_page = 50
  self.per_page = WillPaginate.per_page

  POR_PAGINA = [50, 100, 200, 500, 1000]
  CON_REGION = [19, 50]
  ESTATUSES = [
      [2, 'válido/correcto (✔)'],
      [1, 'sinónimo (✘)']
  ]

  ESTATUSES_SIMBOLO = {
      2 => '✔',
      1 =>'✘'
  }

  ESPECIES_Y_MENORES = %w(19 20 21 22 23 24 50 51 52 53 54 55)

  BUSQUEDAS_TEXTO = {
      1 => 'contiene',
      2 => 'empieza con',
      3 => 'igual a',
      4 => 'termina con'
  }

  BUSQUEDAS_ATRIBUTO = {
      'nombre_cientifico' => 'nombre científico',
      'nombre_comun' => 'nombre común',
      'nombre_region' => 'región',
      'catalogos.descripcion' => 'característica del taxón',
      'nombre_autoridad' => 'autoridad'
  }

  BUSQUEDAS_COMPARADOR = {
      '>' => 'menor a',
      '>=' => 'menor o igual a',
      '=' => 'igual a',
      '<=' => 'mayor o igual a',
      '<' => 'mayor a'
  }

  CAMPOS_A_MOSTRAR = {
      '>' => 'menor a',
      '>=' => 'menor o igual a',
      '=' => 'igual a',
      '<=' => 'mayor o igual a',
      '<' => 'mayor a'
  }

  CATEGORIAS_DIVISION = {
      1 => {
          0 => 'Reino',
          1 => 'Subreino'
      },
      2 => {
          0 => 'División',
          1 => 'Subdivisión'
      },
      3 => {
          0 => 'Clase',
          1 => 'Subclase',
          2 => 'Superorden'
      },
      4 => {
          0 => 'Orden',
          1 => 'Suborden'
      },
      5 => {
          0 => 'Familia',
          1 => 'Subfamilia',
          2 => {
              0 => 'Tribu',
              1 => 'Subtribu'
          }
      },
      6 => {
          0 => 'Género',
          1 => 'Subgénero',
          2 => {
              0 => 'Sección',
              1 => 'Subsección'
          },
          3 => {
              0 => 'Serie',
              1 => 'Subserie'
          }
      },
      7 => {
          0 => 'Especie',
          1 => 'Subespecie',
          2 => {
              0 => 'Variedad',
              1 => 'Subvariedad'
          },
          3 => {
              0 => 'Forma',
              1 => 'Subforma'
          }
      }
  }

  CATEGORIAS_PHYLUM = {
      1 => {
          0 => 'Reino',
          1 => 'Subreino',
          2 => 'Superphylum'
      },
      2 => {
          0 => 'Phylum',
          1 => 'Subphylum',
          2 => 'Superclase',
          3 => 'Grado'
      },
      3 => {
          0 => 'Clase',
          1 => 'Subclase',
          2 => 'Infraclase',
          3 => 'Superorden'
      },
      4 => {
          0 => 'Orden',
          1 => 'Suborden',
          2 => 'Infraorden',
          3 => 'Superfamilia'
      },
      5 => {
          0 => 'Familia',
          1 => 'Subfamilia',
          2 => 'Supertribu',
          3 => {
              0 => 'Tribu',
              1 => 'Subtribu'
          }
      },
      6 => {
          0 => 'Género',
          1 => 'Subgénero',
          2 => {
              0 => 'Sección',
              1 => 'Subsección'
          },
          3 => {
              0 => 'Serie',
              1 => 'Subserie'
          }
      },
      7 => {
          0 => 'Especie',
          1 => 'Subespecie',
          2 => {
              0 => 'Variedad',
              1 => 'Subvariedad'
          },
          3 => {
              0 => 'Forma',
              1 => 'Subforma'
          }
      }
  }

  def self.dameIdsDelNombre(nombre, tipo=nil)
    identificadores=''

    sentencia="SELECT nr.especie_id AS ids FROM nombres_regiones nr
    LEFT JOIN nombres_comunes nc ON nc.id=nr.nombre_comun_id
    WHERE lower_unaccent(nc.nombre_comun) LIKE lower_unaccent('%#{nombre.gsub("'",  "''")}%')"

    sentencia+="UNION SELECT e.id from especies e WHERE lower_unaccent(e.nombre) LIKE lower_unaccent('%#{nombre.gsub("'",  "''")}%')" if tipo.nil?

    sentencia=Especie.find_by_sql(sentencia)

    sentencia.each do |i|
      identificadores+="#{i.ids}, "
    end

    identificadores[0..-3]
  end


  def self.dameIdsDeLaRegion(nombre)
    identificadores=''
    Especie.find_by_sql("SELECT DISTINCT er.especie_id AS ids FROM especies_regiones er
                              LEFT JOIN regiones r ON er.region_id=r.id
                              WHERE lower_unaccent(r.nombre_region) LIKE lower_unaccent('%#{nombre.gsub("'",  "''")}%') ORDER BY ids").each do |i|
      identificadores+="#{i.ids}, "
    end
    identificadores[0..-3]
  end


  def self.dameIdsDeLaDistribucion(distribucion)
    identificadores=''
    Especie.find_by_sql("SELECT DISTINCT er.especie_id AS ids FROM especies_regiones er
                                    WHERE tipo_distribucion_id=#{distribucion} ORDER BY ids;").each do |i|
      identificadores+="#{i.ids}, "
    end
    identificadores[0..-3]
  end

  def self.dameIdsDeConservacion(nombre)
    identificadores=''
    Especie.find_by_sql("SELECT DISTINCT ec.especie_id AS ids FROM especies_catalogos ec
                              LEFT JOIN catalogos c ON ec.catalogo_id=c.id
                              WHERE lower_unaccent(c.descripcion) LIKE lower_unaccent('%#{nombre.gsub("'",  "''")}%') ORDER BY ids").each do |i|
      identificadores+="#{i.ids}, "
    end
    identificadores[0..-3]
  end

  def self.dameIdsCategoria(categoria, id)
    identificadores=''
    Especie.find(id).descendant_ids.each do |des|
      if Especie.find(des).categoria_taxonomica_id == categoria.to_i
        identificadores+="#{des}, "
      end
    end
    identificadores[0..-3]
  end

  private

  def personalizaBusqueda
    "#{self.nombre_cientifico.html_safe} (#{CategoriaTaxonomica.find(self.categoria_taxonomica_id).nombre_categoria_taxonomica})"
  end

  def ponNombreCientifico
    case self.categoria_taxonomica_id
      when 19, 50 #para especies
        generoID=self.ancestry_acendente_obligatorio.split('/').last
        genero=Especie.find(generoID.to_i).nombre
        self.nombre_cientifico="#{genero} #{self.nombre}"
      when 20, 21, 22, 23, 24, 51, 52, 53, 54, 55 #para subespecies
        generoID=self.ancestry_acendente_obligatorio.split('/')[5]
        genero=Especie.find(generoID).nombre
        especieID=self.ancestry_acendente_obligatorio.split('/')[6]
        especie=Especie.find(especieID).nombre
        self.nombre_cientifico="#{genero} #{especie} #{self.nombre}"
      else
        self.nombre_cientifico=self.nombre
    end
  end
end
