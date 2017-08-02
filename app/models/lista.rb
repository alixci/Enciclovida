class Lista < ActiveRecord::Base

  self.table_name = 'listas'
  attr_accessor :taxones, :taxon
  validates :nombre_lista, :presence => true, :uniqueness => true
  before_update :quita_repetidos

  #validates :formato, :presence => true

  ESTATUS_LISTA = [
      [0, 'No'],
      [1, 'Sí']
  ]

  FORMATOS = [
      [1, '.csv'],
      [2, '.xlsx'],
      [3, '.txt']
  ]

  FORMATOS_DESCARGA = %w(csv xlsx txt)

  # Columnas permitidas a exportar por el usuario
  COLUMNAS_PROVEEDORES = %w(catalogo_id x_naturalista_id x_snib_id x_snib_reino)
  COLUMNAS_GEODATOS = %w(x_naturalista_obs x_snib_registros x_geoportal_mapa)
  COLUMNAS_RIESGO_COMERCIO = %w(x_nom x_iucn x_cites)
  COLUMNAS_CATEGORIAS = CategoriaTaxonomica::CATEGORIAS.map{|cat| "x_#{cat}"}
  COLUMNAS_CATEGORIAS_PRINCIPALES = %w(x_reino x_division x_phylum x_clase x_orden x_familia x_genero x_especie)
  COLUMNAS_DEFAULT = %w(id nombre_cientifico x_nombres_comunes x_categoria_taxonomica
                        x_estatus x_tipo_distribucion x_foto_principal
                        cita_nomenclatural nombre_autoridad)
  COLUMNAS_GENERALES = COLUMNAS_DEFAULT + COLUMNAS_RIESGO_COMERCIO + COLUMNAS_CATEGORIAS_PRINCIPALES

  def after_initialize
    self.taxones = []
  end

  # Crea el csv con los datos
  def to_csv(options = {})
    CSV.generate(options) do |csv|
      csv << nombres_columnas
      datos # Completa los datos de los taxones por medio del ID

      taxones.each do |taxon|
        datos_taxon = []

        columnas.split(',').each do |col|
          datos_taxon << eval("taxon.#{col}")
        end
        csv << datos_taxon
      end
    end
  end

  # Para crear el excel con los datos
  def to_excel(opts={})
    xlsx = RubyXL::Workbook.new
    sheet = xlsx[0]
    sheet.sheet_name = 'Resultados'
    fila = 1  # Para no sobreescribir la cabecera
    columna = 0

    # Por si es un string
    if columnas.is_a?(String)
      self.columnas = columnas.split(',')
    end

    # Para la cabecera
    columnas.each do |a|
      sheet.add_cell(0,columna,I18n.t("listas_columnas.generales.#{a}", default: I18n.t("listas_columnas.categorias.#{a}", default: a)))
      columna+= 1
    end

    if opts[:basica]  # Busqueda basica
      t = Busqueda.basica(opts[:nombre], {vista_general: opts[:vista_general], todos: opts[:todos], solo_categoria: opts[:solo_categoria]})
      datos_descarga(t)

    elsif opts[:avanzada]  # Busqueda avanzada
      query = eval(opts[:busqueda]).distinct.to_sql
      consulta = Bases.distinct_limpio(query) << ' ORDER BY nombre_cientifico ASC'
      t = Especie.find_by_sql(consulta)
      datos_descarga(t)
    end

    taxones.each do |taxon|
      if opts[:asignar]
        self.taxon = taxon
        asigna_datos
      else
        self.taxon = taxon
      end
      columna = 0

      columnas.each do |a|
        begin
          sheet.add_cell(fila,columna,taxon.try(a))
        rescue  # Por si existe algun error en la evaluacion de algun campo
          sheet.add_cell(fila,columna,'¡Hubo un error!')
        end
        columna+= 1
      end

      fila+= 1
    end

    # Escribe el excel en cierta ruta
    ruta_excel = Rails.root.join('public','descargas_resultados')
    nombre_archivo = Time.now.strftime("%Y-%m-%d_%H-%M-%S-%L") + '_taxa_EncicloVida'
    FileUtils.mkpath(ruta_excel, :mode => 0755) unless File.exists?(ruta_excel)
    xlsx.write("#{ruta_excel}/#{nombre_archivo}.xlsx")

    if File.exists?("#{ruta_excel}/#{nombre_archivo}.xlsx")
      if opts[:correo].present?
        EnviaCorreo.descargar_taxa("#{CONFIG.site_url}descargas_resultados/#{nombre_archivo}.xlsx", opts[:correo]).deliver
      end

      {estatus: true, excel: "#{CONFIG.site_url}descargas_resultados/#{nombre_archivo}.xlsx"}
    else
      {estatus: true, msg: 'No pudo guardar el archivo'}
    end

  end

  # Para asignar los datos de una lista de ids de especies, hacia un excel o csv, el recurso puede ser un string o un objeto
  def datos(opc={})
    return [] unless cadena_especies.present?

    # Por default muestra todos
    Especie.caso_rango_valores('especies.id',cadena_especies).order('nombre_cientifico ASC').limit(opc[:limit] ||= 300000).each do |taxon|
      self.taxon = taxon
      asigna_datos
      self.taxones << taxon
    end
  end

  # Para asignar los datos de una consulta de resultados, hacia un excel o csv, el recurso puede ser un string o un objeto
  def datos_descarga(taxones)
    return unless taxones.any?

    taxones.each do |taxon|
      self.taxon = taxon
      asigna_datos
      self.taxones << taxon
    end
  end

  # Metodoq ue comparten las listas y para exportar en excel
  def asigna_datos
    return unless taxon.present?

    if columnas.is_a?(String)
      cols = columnas.split(',')
    elsif columnas.is_a?(Array)
      cols = columnas
    end

    cols.each do |col|

      case col
        when 'x_snib_id'
          if proveedor = taxon.proveedor
            self.taxon.x_snib_id = proveedor.snib_id
          end
        when 'x_snib_reino'
          if proveedor = taxon.proveedor
            self.taxon.x_snib_reino = proveedor.snib_reino
          end
        when 'x_naturalista_id'
          if proveedor = taxon.proveedor
            self.taxon.x_naturalista_id = proveedor.naturalista_id
          end
        when 'x_naturalista_obs'
          if proveedor = taxon.proveedor
            self.taxon.x_naturalista_id = proveedor.naturalista_id
          end
        when 'x_snib_registros'
          if proveedor = taxon.proveedor
            self.taxon.x_naturalista_id = proveedor.naturalista_id
          end
        when 'x_geoportal_mapa'
          if proveedor = taxon.proveedor
            self.taxon.x_naturalista_id = proveedor.naturalista_id
          end
        when 'x_categoria_taxonomica'
          self.taxon.x_categoria_taxonomica = taxon.categoria_taxonomica.nombre_categoria_taxonomica
        when 'x_estatus'
          self.taxon.x_estatus = Especie::ESTATUS_SIGNIFICADO[taxon.estatus]
        when 'x_foto_principal'
          if adicional = taxon.adicional
            self.taxon.x_foto_principal = adicional.foto_principal
          end
        when 'x_nombre_comun_principal'
          if adicional = taxon.adicional
            self.taxon.x_nombre_comun_principal = adicional.nombre_comun_principal
          end
        when 'x_nombres_comunes'
          nombres_comunes = taxon.nombres_comunes.order(:nombre_comun).map{|nom| "#{nom.nombre_comun.capitalize} (#{nom.lengua})"}.uniq
          next unless nombres_comunes.any?
          self.taxon.x_nombres_comunes = nombres_comunes.join(',')
        when 'x_tipo_distribucion'
          tipos_distribuciones = taxon.tipos_distribuciones.map(&:descripcion).uniq
          next unless tipos_distribuciones.any?
          self.taxon.x_tipo_distribucion = tipos_distribuciones.join(',')
        when 'x_nom'
          nom = taxon.estados_conservacion.where('nivel1=4 AND nivel2=1 AND nivel3>0').distinct
          next unless nom.length == 1
          self.taxon.x_nom = nom[0].descripcion
        when 'x_iucn'
          iucn = taxon.estados_conservacion.where('nivel1=4 AND nivel2=2 AND nivel3>0').distinct
          next unless iucn.length == 1
          self.taxon.x_iucn = iucn[0].descripcion
        when 'x_cites'
          cites = taxon.estados_conservacion.where('nivel1=4 AND nivel2=3 AND nivel3>0').distinct
          next unless cites.length == 1
          self.taxon.x_cites = cites[0].descripcion
        else
          next
      end  # End switch
    end  # End each cols

    # Para agregar todas las categorias taxonomicas que pidio, primero se intersectan
    cats = COLUMNAS_CATEGORIAS & cols

    if cats.any?
      return unless taxon.ancestry_ascendente_directo.present?
      ids = taxon.path_ids

      Especie.select('nombre, nombre_categoria_taxonomica').categoria_taxonomica_join.where(id: ids).each do |ancestro|
        categoria = 'x_' << I18n.transliterate(ancestro.nombre_categoria_taxonomica).gsub(' ','_').downcase
        next unless COLUMNAS_CATEGORIAS.include?(categoria)
        eval("self.taxon.#{categoria} = ancestro.nombre")  # Asigna el nombre del ancestro si es que coincidio con la categoria
      end
    end
  end

  def nombres_columnas(web = false)
    cabecera = []
    columnas.split(',').each do |col|
      cabecera << I18n.t("listas_columnas.generales.#{col}", default: I18n.t("listas_columnas.categorias.#{col}"))
    end
    web ? cabecera.join(',') : cabecera
  end

  private

  def quita_repetidos
    self.cadena_especies = cadena_especies.split(',').compact.uniq.join(',') if cadena_especies.present?
  end
end
